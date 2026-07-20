#!/bin/sh
# azooKey (azooKey-Desktop) の preference を宣言的に適用する。
#
# 設定実体は container ドメイン dev.ensan.inputmethod.azooKeyMac の
# UserDefaults。Codable 値は JSON エンコードされた Data（hex）で持つ
# （例: "custom" = 0x22637573746f6d22）。
# - input_style=custom: カスタムローマ字テーブル
#   (~/Library/Containers/.../azooKeyMac/CustomInputTable/custom_input_table.tsv、
#   chezmoi 管理) を有効化。テーブルは既定表の全置換なので既定行も同 TSV に含む。
# - typeHalfSpace=true: 日本語モードでもスペースは常に半角。
#
# 反映には azooKey の再起動が必要だが、アクティブな IME の連続 kill は
# macOS が入力ソース一覧から azooKey を外す事故があるため自動では行わない。
# 手動反映: 入力ソースを一旦 ABC にしてから
#   killall azooKeyMac; sleep 1; open "/Library/Input Methods/azooKeyMac.app"
set -u

domain="dev.ensan.inputmethod.azooKeyMac"
prefix="${domain}.preference"

defaults write "$domain" "${prefix}.input_style" -data 22637573746f6d22 || true
defaults write "$domain" "${prefix}.typeHalfSpace" -bool true || true
