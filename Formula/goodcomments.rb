class Goodcomments < Formula
  desc "Feedback tracker at the edge of your screen: open, fixed by you or your agents, done"
  homepage "https://github.com/sdezubiria/goodcomments"
  url "https://github.com/sdezubiria/goodcomments/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "426d5643f423c6c2c8c828f0f8da5c7bd1b1c55cce06c7382f8dc5491e95c7e6"
  license "MIT"

  depends_on :macos
  depends_on "node"

  def install
    libexec.install Dir["*"]
    (bin/"gc").write_env_script libexec/"bin/gc.js", PATH: "#{Formula["node"].opt_bin}:$PATH"

    # The menu bar app is built here (needs Swift from the Xcode Command Line Tools).
    # Ad-hoc signed: Homebrew builds can't use your keychain's signing identity.
    cd libexec/"mac" do
      unless quiet_system({ "GOODCOMMENTS_SIGN_IDENTITY" => "-" }, "sh", "build.sh")
        opoo "Couldn't build the menu bar app (install the Command Line Tools: xcode-select --install). " \
             "The board still works in the browser: gc open"
      end
    end
  end

  service do
    run [opt_bin/"gc", "serve"]
    keep_alive true
    log_path var/"log/goodcomments.log"
    error_log_path var/"log/goodcomments.log"
  end

  def caveats
    <<~EOS
      Open the menu bar app (rest the pointer on the right edge of the screen, or press ⌃⌥C):
        open #{opt_libexec}/mac/build/GoodComments.app
      To find it in Launchpad / Spotlight, link it into ~/Applications:
        ln -sf #{opt_libexec}/mac/build/GoodComments.app ~/Applications/GoodComments.app

      Run the server at login (the app also starts it when needed):
        brew services start goodcomments

      Give Claude Code the tools:
        claude mcp add goodcomments -s user -- #{opt_bin}/gc mcp

      Your comments are stored in ~/.goodcomments.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gc version")
    port = free_port
    ENV["GOODCOMMENTS_PORT"] = port.to_s
    ENV["GOODCOMMENTS_DB"] = (testpath/"test.db").to_s
    pid = spawn bin/"gc", "serve"
    begin
      sleep 2
      system bin/"gc", "project", "add", "Test"
      assert_match "Hung", shell_output("#{bin}/gc add 'The logo is blurry' -p test")
      assert_match "The logo is blurry", shell_output("#{bin}/gc list --all")
    ensure
      Process.kill("TERM", pid)
    end
  end
end
