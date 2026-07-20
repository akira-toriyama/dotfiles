// stdin のプロンプトを FoundationModels (Apple Intelligence オンデバイスモデル) に
// 渡し、応答テキストを stdout へ印字するだけの最小 CLI。azookey-bridge.py が
// Ctrl+S のたびに呼ぶ (~1 秒/回)。run_onchange_after_azookey-bridge.sh.tmpl が
// swiftc でこの隣に `fm-predict` としてコンパイルする。
//
// maximumResponseTokens は生成暴走 (context 4096 を食い潰して
// exceededContextWindowSize になる実測挙動) へのガード。
import FoundationModels
import Foundation

let data = FileHandle.standardInput.readDataToEndOfFile()
guard let prompt = String(data: data, encoding: .utf8), !prompt.isEmpty else {
    FileHandle.standardError.write("fm-predict: empty prompt\n".data(using: .utf8)!)
    exit(2)
}
let model = SystemLanguageModel.default
guard case .available = model.availability else {
    FileHandle.standardError.write("fm-predict: FoundationModels unavailable: \(model.availability)\n".data(using: .utf8)!)
    exit(3)
}
let session = LanguageModelSession(model: model)
let r = try await session.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 600))
print(r.content)
