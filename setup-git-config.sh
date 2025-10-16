#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -------------------------------------
# setup-git-config.sh
#
# Git user.name / user.email 설정 스크립트
#
# ⚠️ Run in Bash (macOS, Linux, WSL, or Git Bash on Windows)
# -------------------------------------

# ---------- utils ----------
log()   { printf "%s\n" "🔹 $*"; }
warn()  { printf "%s\n" "⚠️  $*" >&2; }
err()   { printf "%s\n" "❌ $*" >&2; }
ok()    { printf "%s\n" "✅ $*"; }

usage() {
  cat <<'EOF'
Usage:
  setup-git-config.sh [--name "홍길동"] [--email "dev@example.com"] [--global|--local]
                      [--yes] [--show-only]

Options:
  --name        : 설정할 user.name
  --email       : 설정할 user.email
  --global      : 전역 설정(~/.gitconfig)에 적용 (기본값)
  --local       : 현재 리포지토리(.git/config)에 적용
  --yes         : 확인 질문 없이 진행(비대화식 CI 등)
  --show-only   : 적용하지 않고 현재 값을 출력만 함
  -h, --help    : 도움말

Examples:
  ./setup-git-config.sh --name "Hong Gil-dong" --email dev@company.com --global --yes
  ./setup-git-config.sh --local                # 로컬 설정만 대화식으로 입력
  ./setup-git-config.sh --show-only --global   # 현재 설정 보기
EOF
}

# ---------- prerequisites ----------
command -v git >/dev/null 2>&1 || { err "git 이 설치되어 있지 않습니다."; exit 127; }

# ---------- defaults & args ----------
SCOPE="--global"
YES="false"
SHOW_ONLY="false"
NAME="${GIT_USER_NAME:-}"
EMAIL="${GIT_USER_EMAIL:-}"

while [[ "${1-}" != "" ]]; do
  case "$1" in
    --name)   shift; NAME="${1-}";;
    --email)  shift; EMAIL="${1-}";;
    --global) SCOPE="--global";;
    --local)  SCOPE="--local";;
    --yes)    YES="true";;
    --show-only) SHOW_ONLY="true";;
    -h|--help) usage; exit 0;;
    *) err "알 수 없는 옵션: $1"; usage; exit 2;;
  esac
  shift || true
done

# ---------- helpers ----------
get_current() {
  local key="$1"
  if git config $SCOPE --get "$key" >/dev/null 2>&1; then
    git config $SCOPE --get "$key"
  else
    echo ""
  fi
}

confirm() {
  local prompt="$1"
  if [[ "$YES" == "true" ]]; then
    return 0
  fi
  printf "%s [y/N]: " "$prompt"
  read -r ans || true
  # Bash 3.2 호환: 소문자 변환을 tr로 처리
  ans="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
  [[ "$ans" == "y" || "$ans" == "yes" ]]
}

is_valid_email() {
  # 느슨한 형식 검증: something@something.something
  [[ "$1" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]
}

# ---------- show-only mode ----------
if [[ "$SHOW_ONLY" == "true" ]]; then
  scope_label=$([[ "$SCOPE" == "--global" ]] && echo "GLOBAL" || echo "LOCAL")
  log "현재 Git 설정($scope_label):"
  printf "  user.name : %s\n" "$(get_current user.name || true)"
  printf "  user.email: %s\n" "$(get_current user.email || true)"
  exit 0
fi

# ---------- interactive prompts if missing ----------
if [[ -z "${NAME}" ]]; then
  printf "✨ Enter your name (e.g. 홍길동): "
  read -r NAME || true
fi
if [[ -z "${EMAIL}" ]]; then
  printf "📩 Enter your email (e.g. dev@company.com): "
  read -r EMAIL || true
fi

# ---------- validations ----------
if [[ -z "$NAME" ]]; then
  err "이름(user.name)은 비워둘 수 없습니다."
  exit 1
fi
if [[ -z "$EMAIL" ]]; then
  err "이메일(user.email)은 비워둘 수 없습니다."
  exit 1
fi
if ! is_valid_email "$EMAIL"; then
  err "이메일 형식이 올바르지 않습니다: $EMAIL"
  exit 1
fi

# ---------- current values & noop short-circuit ----------
CUR_NAME="$(get_current user.name || true)"
CUR_EMAIL="$(get_current user.email || true)"
scope_label=$([[ "$SCOPE" == "--global" ]] && echo "GLOBAL" || echo "LOCAL")

log "적용 범위: $scope_label"
printf "  현재 user.name : %s\n" "${CUR_NAME:-<unset>}"
printf "  현재 user.email: %s\n" "${CUR_EMAIL:-<unset>}"
printf "  신규 user.name : %s\n" "$NAME"
printf "  신규 user.email: %s\n" "$EMAIL"

if [[ "$CUR_NAME" == "$NAME" && "$CUR_EMAIL" == "$EMAIL" ]]; then
  ok "이미 동일한 값으로 설정되어 있어 변경할 사항이 없습니다.\n"
  exit 0
fi

# ---------- confirm overwrite if changing ----------
if [[ -n "$CUR_NAME" && "$CUR_NAME" != "$NAME" ]] || [[ -n "$CUR_EMAIL" && "$CUR_EMAIL" != "$EMAIL" ]]; then
  if ! confirm "기존 값을 새 값으로 덮어쓸까요?"; then
    warn "사용자 요청으로 중단했습니다."
    exit 0
  fi
fi

# ---------- apply ----------
git config $SCOPE user.name  "$NAME"
git config $SCOPE user.email "$EMAIL"

# ---------- summary ----------
NEW_NAME="$(get_current user.name || true)"
NEW_EMAIL="$(get_current user.email || true)"

ok "Your information has been set as follows 👇"
printf "\n  user.name : %s\n" "$NEW_NAME"
printf "  user.email: %s\n" "$NEW_EMAIL"
printf "\n🎉 All setup complete. BYE!!\n"
