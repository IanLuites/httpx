# HTTPX.get(, auth: :basic, username: "username99", password: "password99", format: :json)
# [
#   {"authorization", "Basic dXNlcm5hbWU5OTpwYXNzd29yZDk5"},
#   {"user-agent", "HTTPX/0.1.0"}
# ]

defmodule HTTPX.Auth.BasicTest do
  use ExUnit.Case, async: true

  @username "FrankenFurter"
  @password "Secret789!"
  @url "https://httpbin.org/basic-auth/#{@username}/#{@password}"

  test "gains access with basic auth" do
    assert HTTPX.get!(@url,
             auth: :basic,
             username: @username,
             password: @password,
             format: :json
           ).body["authenticated"] == true
  end

  describe "fails with" do
    test "no auth" do
      assert HTTPX.get!(@url).status == 401
    end

    test "wrong username" do
      assert HTTPX.get!(@url,
               auth: :basic,
               username: @username <> "FAKE",
               password: @password
             ).status == 401
    end

    test "wrong password" do
      assert HTTPX.get!(@url,
               auth: :basic,
               username: @username,
               password: @password <> "FAKE"
             ).status == 401
    end
  end
end
