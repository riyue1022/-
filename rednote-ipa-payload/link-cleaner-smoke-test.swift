import Foundation

let sample = "https://www.xiaohongshu.com/discovery/item/6af18d37000000002c014308?app_platform=ios&app_version=9.43.2&share_from_user_hidden=true&xsec_source=app_share&type=normal&xsec_token=KEEP_ME&author_share=1&xhsshare=TRACK&shareRedId=PRIVATE&foo=bar&utm_source=chat"
let standard = try LinkPrivacyCleaner.clean(sample)
let standardURL = standard.cleanedURL.absoluteString
precondition(standardURL.contains("xsec_token=KEEP_ME"))
precondition(standardURL.contains("type=normal"))
precondition(standardURL.contains("foo=bar"))
precondition(!standardURL.contains("shareRedId"))
precondition(!standardURL.contains("author_share"))
precondition(!standardURL.contains("utm_source"))
precondition(standard.removedParameters.count == 8)

let strict = try LinkPrivacyCleaner.clean(sample, preserveAccessToken: false)
precondition(!strict.cleanedURL.absoluteString.contains("xsec_token"))
precondition(strict.removedParameters.count == 9)

let short = try LinkPrivacyCleaner.clean("https://xhslink.cn/o/4YZ2WnojZpx?shareRedId=secret&xsec_source=app_share")
precondition(short.isShortLink)
precondition(!short.cleanedURL.absoluteString.contains("shareRedId"))

let unsupported = try? LinkPrivacyCleaner.clean("https://example.com/?shareRedId=secret")
precondition(unsupported == nil)

print("PASS: standard mode, strict mode, short links, and domain validation")
