# frozen_string_literal: true

require "sinatra"
require "sinatra/reloader" if development?
require "json"
require "sqlite3"
require "acme-client"
require "openssl"

class RedirectorApp < Sinatra::Base
  DB_PATH = File.join(settings.root, "db", "redirects.db")
  EMAIL_ADDRESS = "ljuti@neuraljets.com"

  before do
    content_type :json
  end

  get "/api/redirects" do
    db = SQLite3::Database.new(DB_PATH)
    db.results_as_hash = true

    results = db.execute("SELECT * FROM redirects")
    results.to_json
  ensure
    db.close if db
  end

  get "/*" do
    domain = normalize_domain(request.host)
    redirect_url = find_redirect(domain)

    if redirect_url
      target_url = [redirect_url, request.fullpath].join
      redirect target_url, 301
    else
      erb :not_found
    end
  end

  post "/api/redirects" do
    data = JSON.parse(request.body.read)
    domain = data["domain"]
    target_url = data["target_url"]

    if domain && target_url
      db = SQLite3::Database.new(DB_PATH)
      db.execute("INSERT INTO redirects (domain, target_url) VALUES (?, ?)", [domain, target_url])
      status 201
      { message: "Redirect created" }.to_json

      request_ssl_certificate(domain)
    else
      status 400
      { message: "Invalid parameters" }.to_json
    end
  ensure
    db.close if db
  end

  delete "/api/redirects/:domain" do
    domain = params[:domain]

    db = SQLite3::Database.new(DB_PATH)
    db.execute("DELETE FROM redirects WHERE domain = ?", [domain])
    { message: "Redirect deleted" }.to_json
  ensure
    db.close if db
  end

  private

  def normalize_domain(domain)
    domain.sub(/^www\./, "")
  end

  def find_redirect(domain)
    db = SQLite3::Database.new(DB_PATH)
    db.results_as_hash = true

    result = db.get_first_row("SELECT target_url FROM redirects WHERE domain = ?", [domain])
    result ? result["target_url"] : nil
  ensure
    db.close if db
  end

  def request_ssl_certificate(domain)
    private_key = OpenSSL::PKey::RSA.new(4096)
    private_key_2 = OpenSSL::PKey::RSA.new(4096)

    endpoint = ENV["ACME_ENDPOINT"] || "https://acme-v02.api.letsencrypt.org/directory"
    client = Acme::Client.new(private_key: private_key, directory: endpoint)
    account = client.new_account(contact: "mailto:#{EMAIL_ADDRESS}", terms_of_service_agreed: true)
    order = client.new_order(identifiers: [domain])

    authorization = order.authorizations.first
    challenge = authorization.http01

    challenge_file_path = File.join(settings.public_folder, challenge.filename)
    File.write(challenge_file_path, challenge.file_content)

    # Request the challenge validation
    challenge.request_validation

    # Poll the status of the challenge
    while challenge.status == 'pending'
      sleep(2)
      challenge.reload
    end

    if challenge.status == 'valid'
      csr = Acme::Client::CertificateRequest.new(private_key: private_key_2, subject: { common_name: domain })
      order.finalize(csr: csr)
      sleep(1) while order.status == 'processing'
      if order.status == 'valid'
        certificate = order.certificate
        # Save the certificate and private key
        File.write("/etc/letsencrypt/live/#{domain}/fullchain.pem", certificate.to_pem)
        File.write("/etc/letsencrypt/live/#{domain}/privkey.pem", private_key.to_pem)
        { message: 'SSL certificate obtained and saved' }.to_json
      else
        { error: 'Failed to finalize SSL certificate order' }.to_json
      end
    else
      { error: "Failed to obtain SSL certificate, challenge status: #{challenge.status}.", order_url: order.url }.to_json
    end
  rescue => e
    { error: e.message }.to_json
  end
end

# run Redirector.run!