import Foundation
// Probe-only: MediaRemote is a private framework; read-only Now Playing info.
guard let h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) else {
  print("NOLIB"); exit(0)
}
typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
guard let sym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") else { print("NOSYM"); exit(0) }
let getInfo = unsafeBitCast(sym, to: GetInfoFn.self)
func key(_ name: String) -> String {
  guard let k = dlsym(h, name) else { return name }
  return k.assumingMemoryBound(to: Optional<CFString>.self).pointee.map { $0 as String } ?? name
}
let titleKey = key("kMRMediaRemoteNowPlayingInfoTitle")
let rateKey = key("kMRMediaRemoteNowPlayingInfoPlaybackRate")
let sem = DispatchSemaphore(value: 0)
var info: [String: Any]? = nil
getInfo(DispatchQueue.global()) { d in
  info = d
  sem.signal()
}
_ = sem.wait(timeout: .now() + 8)
if let d = info {
  print("TITLE=\(d[titleKey] as? String ?? "")")
  print("RATE=\(d[rateKey] as? Double ?? -1)")
} else {
  print("NOINFO")
}