local oauth = require 'OAuth'

local auth = {}

function auth.getValues(key, secret)
    local client = oauth.new(key, secret, {
        RequestToken = 'https://api.twitter.com/oauth/request_token',
        AuthorizeUser = {"http://api.twitter.com/oauth/authorize", method = "GET"},
        AccessToken = 'https://api.twitter.com/oauth/access_token'
    })

    local callback_url = "oob"
    local values = client:RequestToken({ oauth_callback = callback_url })
    local oauth_token = values.oauth_token  -- we'll need both later
    local oauth_token_secret = values.oauth_token_secret

    local tracking_code = "90210"   -- this is some random value
    local new_url = client:BuildAuthorizationUrl({ oauth_callback = callback_url, state = tracking_code })

    print("Navigate to this url with your browser, please...")
    print(new_url)
    print("\r\nOnce you have logged in and authorized the application, enter the PIN")

    local oauth_verifier = assert(io.read("*n"))    -- read the PIN from stdin
    oauth_verifier = tostring(oauth_verifier)       -- must be a string

    local client = oauth.new(key, secret, {
        RequestToken = 'https://api.twitter.com/oauth/request_token',
        AuthorizeUser = {"http://api.twitter.com/oauth/authorize", method = "GET"},
        AccessToken = 'https://api.twitter.com/oauth/access_token'
    }, {
        OAuthToken = oauth_token,
        OAuthVerifier = oauth_verifier
    })
    client:SetTokenSecret(oauth_token_secret)

    --local values, err, headers, status, body = 
    return client:GetAccessToken()
end

return auth

