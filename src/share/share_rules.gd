class_name ShareRules
extends RefCounted
## Shares a drive result to Telegram, the main messenger in Uzbekistan: the Telegram app's
## share screen, or Telegram's web share page when the app cannot be opened. No plugin.


static func app_url(text: String) -> String:
	return "tg://msg?text=" + text.uri_encode()


static func web_url(text: String) -> String:
	return "https://t.me/share/url?url=" + text.uri_encode()


## Opens Telegram with text and returns the address used. Headless runs (tests) open nothing.
static func open(text: String) -> String:
	if DisplayServer.get_name() == "headless":
		return app_url(text)
	if OS.shell_open(app_url(text)) == OK:
		return app_url(text)
	OS.shell_open(web_url(text))
	return web_url(text)
