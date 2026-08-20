#!/usr/bin/env bash
# Senbrix Runtime 설치 스크립트 (Raspberry Pi, 64bit/32bit Raspberry Pi OS)
#
#   curl -sSL https://raw.githubusercontent.com/going-kr/Release.Senbrix/master/install-runtime.sh | sudo bash
#   curl -sSL .../install-runtime.sh | sudo bash -s -- --version 0.9.0     # 버전 고정
#   sudo bash install-runtime.sh --tarball ./Senbrix-runtime-0.9.0-linux.tar.gz   # 오프라인(미리 받은 tar.gz)
#   sudo bash install-runtime.sh --can-port can0     # CAN 포트 지정(질문 생략). 사용 안 함은 --can-port none
#
# 정본은 Senbrix 소스 리포 deploy/install-runtime.sh — scripts/release.ps1 -Target runtime 이 Release.Senbrix 리포에 같은 내용을 올린다.
#
# 하는 일:
#   1. .NET 9 ASP.NET Core 런타임을 /opt/dotnet 에 설치 (공식 dotnet-install.sh, arm64/arm32 자동)  [--no-dotnet 로 생략]
#   2. 런타임 릴리스(태그 runtime-v<버전>, 에디터 릴리스 v<버전>과 별개)의 Senbrix-runtime-<버전>-linux.tar.gz 를
#      받아 /opt/senbrix 에 설치 (버전 미지정 시 runtime-v* 중 최신. 재설치/업데이트 시 Apps/ · Logs/ · appsettings.json 은 보존)
#   3. CAN 확장 보드 버스 사용 여부를 물어 appsettings 의 Runtime:CanPort 설정 (사용 안 하면 그냥 엔터)
#   4. 전용 사용자 senbrix(gpio·dialout 그룹) + systemd 서비스 senbrix-runtime 등록·기동
# 되돌리기: sudo systemctl disable --now senbrix-runtime; sudo rm -rf /opt/senbrix /etc/systemd/system/senbrix-runtime.service
set -euo pipefail

REPO="going-kr/Release.Senbrix"
VERSION=""            # 비면 latest
TARBALL=""            # 로컬 tar.gz 경로(오프라인)
CAN_OPT=""            # --can-port 값 (none = 사용 안 함). 비면 대화형 질문
CAN_OPT_SET=0
INSTALL_DOTNET=1
DOTNET_DIR="/opt/dotnet"
APP_DIR="/opt/senbrix"
SVC_USER="senbrix"
SVC_NAME="senbrix-runtime"

while [ $# -gt 0 ]; do
  case "$1" in
    --version)   VERSION="$2"; shift 2 ;;
    --tarball)   TARBALL="$2"; shift 2 ;;
    --can-port)  CAN_OPT="$2"; CAN_OPT_SET=1; shift 2 ;;
    --no-dotnet) INSTALL_DOTNET=0; shift ;;
    -h|--help)   sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then echo "root 권한이 필요합니다: sudo bash $0" >&2; exit 1; fi
if ! command -v curl >/dev/null; then apt-get update -qq && apt-get install -y -qq curl; fi

step() { printf '\n\033[1;35m== %s\033[0m\n' "$*"; }

# ── 1. .NET 9 ASP.NET Core 런타임 ─────────────────────────────────────────────
if [ "$INSTALL_DOTNET" -eq 1 ]; then
  if [ -x "$DOTNET_DIR/dotnet" ] && "$DOTNET_DIR/dotnet" --list-runtimes 2>/dev/null | grep -q '^Microsoft.AspNetCore.App 9\.'; then
    step ".NET 9 ASP.NET Core 런타임: 이미 설치됨 ($DOTNET_DIR)"
  else
    step ".NET 9 ASP.NET Core 런타임 설치 -> $DOTNET_DIR"
    apt-get update -qq && apt-get install -y -qq libicu-dev libssl-dev >/dev/null   # .NET 네이티브 의존
    tmp="$(mktemp)"; curl -sSL https://dot.net/v1/dotnet-install.sh -o "$tmp"
    bash "$tmp" --channel 9.0 --runtime aspnetcore --install-dir "$DOTNET_DIR"
    rm -f "$tmp"
  fi
  ln -sf "$DOTNET_DIR/dotnet" /usr/local/bin/dotnet
  grep -q 'DOTNET_ROOT=' /etc/environment 2>/dev/null || echo "DOTNET_ROOT=$DOTNET_DIR" >> /etc/environment
fi
DOTNET_BIN="$DOTNET_DIR/dotnet"; [ -x "$DOTNET_BIN" ] || DOTNET_BIN="$(command -v dotnet || true)"
if [ -z "$DOTNET_BIN" ]; then echo "dotnet 을 찾을 수 없습니다. --no-dotnet 없이 다시 실행하세요." >&2; exit 1; fi
"$DOTNET_BIN" --list-runtimes | grep -q '^Microsoft.AspNetCore.App 9\.' || { echo "Microsoft.AspNetCore.App 9.x 런타임이 없습니다." >&2; exit 1; }

# ── 2. 런타임 파일 ────────────────────────────────────────────────────────────
step "Senbrix 런타임 받기"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
if [ -n "$TARBALL" ]; then
  cp "$TARBALL" "$work/runtime.tar.gz"
else
  if [ -z "$VERSION" ]; then
    # 런타임 릴리스는 태그 runtime-v<버전> — releases/latest 는 에디터 릴리스일 수 있어 API 로 태그를 고른다(최신순)
    VERSION="$(curl -sSL "https://api.github.com/repos/$REPO/releases?per_page=50" | sed -n 's/.*"tag_name": *"runtime-v\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$VERSION" ] || { echo "최신 버전을 조회하지 못했습니다. --version 으로 지정하세요." >&2; exit 1; }
  fi
  url="https://github.com/$REPO/releases/download/runtime-v$VERSION/Senbrix-runtime-$VERSION-linux.tar.gz"
  echo "  $url"
  curl -fSL "$url" -o "$work/runtime.tar.gz"
fi
mkdir -p "$work/new" && tar -xzf "$work/runtime.tar.gz" -C "$work/new"
[ -f "$work/new/Senbrix.Runtime.dll" ] || { echo "tar.gz 안에 Senbrix.Runtime.dll 이 없습니다." >&2; exit 1; }

step "설치 -> $APP_DIR"
id -u "$SVC_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$SVC_USER"
for g in gpio dialout; do getent group "$g" >/dev/null && usermod -aG "$g" "$SVC_USER" || true; done
systemctl stop "$SVC_NAME" 2>/dev/null || true
mkdir -p "$APP_DIR"
# 보존: Apps/(배포된 앱) · Logs/ · appsettings.json(사용자 설정, 예: CanPort)
if [ -f "$APP_DIR/appsettings.json" ]; then cp "$APP_DIR/appsettings.json" "$work/appsettings.keep.json"; fi
find "$APP_DIR" -mindepth 1 -maxdepth 1 ! -name Apps ! -name Logs -exec rm -rf {} +
cp -a "$work/new/." "$APP_DIR/"
if [ -f "$work/appsettings.keep.json" ]; then cp "$work/appsettings.keep.json" "$APP_DIR/appsettings.json"; fi

# ── 2b. CAN 포트 (확장 보드 버스 — appsettings Runtime:CanPort) ───────────────
# 미설정이면 코드 기본값 can0 으로 GoCanBus 가 시작된다 — CAN 없는 보드에선 3초마다 재접속 경고가
# 계속 쌓이므로 설치 때 사용 여부를 확정한다. 값 결정: --can-port > 대화형(/dev/tty) > 터미널 없으면 기존 유지.
step "CAN 포트 (확장 보드 버스)"
AS="$APP_DIR/appsettings.json"
read_canport() {  # 현재 설정 출력: 인터페이스명 / 빈 값(사용 안 함) / __absent__(미설정 = 기본 can0)
  python3 - "$AS" <<'PY' 2>/dev/null || echo "__absent__"
import json, sys
d = json.load(open(sys.argv[1])).get("Runtime", {})
v = d.get("CanPort", "__absent__")
print("" if v is None else v, end="")
PY
}
write_canport() {
  python3 - "$AS" "$1" <<'PY'
import json, sys
p, v = sys.argv[1], sys.argv[2]
try: d = json.load(open(p))
except Exception: d = {}
d.setdefault("Runtime", {})["CanPort"] = v
open(p, "w").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
PY
  echo "  Runtime:CanPort = ${1:-(사용 안 함)}"
}
if ! command -v python3 >/dev/null; then
  echo "  python3 없음 — CanPort 설정 생략. 필요 시 $AS 의 Runtime:CanPort 를 직접 수정하세요."
elif [ "$CAN_OPT_SET" -eq 1 ]; then
  [ "$CAN_OPT" = "none" ] && CAN_OPT=""
  write_canport "$CAN_OPT"
elif { : </dev/tty; } 2>/dev/null; then
  if [ -f "$work/appsettings.keep.json" ]; then
    cur="$(read_canport)"
    case "$cur" in
      __absent__) cur_disp="can0 (기본값)" ;;
      "")         cur_disp="사용 안 함" ;;
      *)          cur_disp="$cur" ;;
    esac
    read -rp "CAN 확장 보드 버스 — 현재: $cur_disp. 엔터 = 유지, 사용 안 하면 none, 바꾸려면 인터페이스명(예: can0): " ans </dev/tty || ans=""
    if [ -n "$ans" ]; then
      [ "$ans" = "none" ] && ans=""
      write_canport "$ans"
    else
      echo "  현재 설정 유지"
    fi
  else
    read -rp "CAN 확장 보드 버스를 사용하면 인터페이스명 입력(예: can0), 사용 안 하면 그냥 엔터: " ans </dev/tty || ans=""
    [ "$ans" = "none" ] && ans=""
    write_canport "$ans"
  fi
else
  echo "  터미널 없음 — 질문 생략(현재 설정 유지). --can-port <이름|none> 옵션으로 지정할 수 있습니다."
fi

chown -R "$SVC_USER:$SVC_USER" "$APP_DIR"

# ── 3. systemd ────────────────────────────────────────────────────────────────
step "systemd 서비스 $SVC_NAME"
cat > "/etc/systemd/system/$SVC_NAME.service" <<EOF
[Unit]
Description=Senbrix Runtime (PLC)
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
User=$SVC_USER
WorkingDirectory=$APP_DIR
Environment=DOTNET_ROOT=$(dirname "$DOTNET_BIN")
ExecStart=$DOTNET_BIN $APP_DIR/Senbrix.Runtime.dll
Restart=always
RestartSec=5
SyslogIdentifier=$SVC_NAME

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now "$SVC_NAME"
sleep 3
systemctl --no-pager --lines=5 status "$SVC_NAME" || true

ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
printf '\n\033[1;32m설치 완료.\033[0m 에디터의 장치 연결 목록에 %s(%s) 가 뜹니다. 방화벽을 쓰면 5557/tcp·5555/tcp·5353/udp 를 여세요.\n' "$(hostname)" "${ip:-?}"
echo "로그: journalctl -u $SVC_NAME -f    설정: $APP_DIR/appsettings.json (Runtime:CanPort 등)"
