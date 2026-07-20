{ username, ... }:

{
  # 自作キーボード dongle (ZMK BLE HID Host) のシリアルログを 24/7 常駐キャプチャする
  # LaunchAgent（launchd-drift / claude-maint と同じ流儀）。dongle 安定化までの調査用で、
  # 撤去は zmk-ble-hid-host t-x0ak (icebox) が管理する。
  #
  # スクリプト本体は chezmoi 所有の ~/.local/bin/zmk-log-capture.sh（照会 CLI は同
  # ~/.local/bin/zmk-log）。手編集で育てる生スクリプトなので claude-maint のような
  # Nix store コピー (${./...}) にせず、1 ファイル 1 所有の原則で chezmoi に置く。
  # ログ実体 ~/zmk-logs/ は state（管理外・script が mkdir -p で自作）。
  #
  # 旧: 手置きの ~/Library/LaunchAgents/com.tommy.zmk-log.plist ＋ ~/bin/ 直下の
  # スクリプト（PC 初期化のたび手で再構築していた）。この宣言が置換する (t-pfsd)。
  launchd.user.agents.zmk-log = {
    serviceConfig = {
      Label = "org.nixos.zmk-log";
      ProgramArguments = [
        "/bin/bash"
        "/Users/${username}/.local/bin/zmk-log-capture.sh"
      ];
      # login 時に起動し、process が死んだら launchd が再起動（USB 抜き差しは
      # script 内 loop が追従するので KeepAlive の出番は異常死のみ）。
      RunAtLoad = true;
      KeepAlive = true;
      # 旧 plist は ~/zmk-logs/launchd.{out,err} だったが、新 Mac 初回起動時に
      # dir 不在で launchd が開けない縁を踏まないよう /tmp に置く（家風も /tmp）。
      StandardOutPath = "/tmp/zmk-log-capture.log";
      StandardErrorPath = "/tmp/zmk-log-capture.log";
    };
  };
}
