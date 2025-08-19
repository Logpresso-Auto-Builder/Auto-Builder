#!/usr/bin/env bash
# Re-exec with bash if not already in bash
if [ -z "${BASH_VERSION:-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi
set -euo pipefail

VERSION="version0.0.0.1"

draw_logo() {
	cat <<'EOF'
_________ _______  _______  _______  _______           _______ 
\__   __/(  ____ \(  ____ )(  ___  )(  ____ \|\     /|(  ____ \
   ) (   | (    \/| (    )|| (   ) || (    \/( \   / )| (    \/
   | |   | (__    | (____)|| (___) || (_____  \ (_) / | (_____ 
   | |   |  __)   |     __)|  ___  |(_____  )  \   /  (_____  )
   | |   | (      | (\ (   | (   ) |      ) |   ) (         ) |
   | |   | (____/\| ) \ \__| )   ( |/\____) |   | |   /\____) |
   )_(   (_______/|/   \__/|/     \|\_______)   \_/   \_______)
                                                                
EOF
}

print_separator() {
  local cols
  cols=$(tput cols 2>/dev/null || echo 80)
  printf '%*s\n' "$cols" '' | tr ' ' '-'
}

print_banner() {
  local title="$1"
  print_separator
  printf "✦ %s ✦\n" "$title"
  print_separator
}

show_menu() {
  local title="$1"; shift
  local -a items=("$@")
  print_banner "$title"
  local i=1
  for it in "${items[@]}"; do printf "  %2d) %s\n" "$i" "$it"; ((i++)); done
  print_separator
}

show_menu_with_back() {
  local title="$1"; shift
  local -a items=("$@")
  print_banner "$title"
  printf "  %2d) %s\n" 0 "뒤로가기"
  local i=1
  for it in "${items[@]}"; do printf "  %2d) %s\n" "$i" "$it"; ((i++)); done
  print_separator
}

read_choice() {
  local max="$1"; local prompt="$2"; local ans=""
  while :; do
    if [[ -r /dev/tty ]]; then
      read -r -p "$prompt " ans < /dev/tty || true
    else
      read -r -p "$prompt " ans || true
    fi
    ans=${ans//$'\r'/}
    ans=${ans//[[:space:]]/}
    [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans>=1 && ans<=max )) && { echo "$ans"; return 0; }
    echo "잘못된 입력입니다. (1-${max})" >&2
  done
}

read_choice_zero() {
  local max="$1"; local prompt="$2"; local ans=""
  while :; do
    if [[ -r /dev/tty ]]; then
      read -r -p "$prompt " ans < /dev/tty || true
    else
      read -r -p "$prompt " ans || true
    fi
    ans=${ans//$'\r'/}
    ans=${ans//[[:space:]]/}
    [[ "${ans}" =~ ^[0-9]+$ ]] && (( ans>=0 && ans<=max )) && { echo "$ans"; return 0; }
    echo "잘못된 입력입니다. (0-${max})" >&2
  done
}

read_choice_framed() {
  local max="$1"; local label="$2"
  read_choice "$max" "❯ 입력"
}

progress_bar() {
  # Progress visuals disabled to avoid multi-line output issues
  return 0
}

interactive_menu() {
  local title="$1"; shift
  local -a items=("$@")
  local idx=0 key=""
  tput sc 2>/dev/null || true
  tput civis 2>/dev/null || true
  while :; do
    tput rc 2>/dev/null || true
    tput ed 2>/dev/null || true
    print_banner "$title"
    for i in "${!items[@]}"; do
      if (( i == idx )); then
        printf "  ▶ \033[32m%s\033[0m\n" "${items[$i]}"
      else
        printf "    %s\n" "${items[$i]}"
      fi
    done
    print_separator
    echo "⬆/⬇ 이동, Enter 선택"
    if [[ -r /dev/tty ]]; then
      IFS= read -rsn1 key < /dev/tty || true
    else
      IFS= read -rsn1 key || true
    fi
    if [[ "${key}" == $'\x1b' ]]; then
      if [[ -r /dev/tty ]]; then
        IFS= read -rsn2 key < /dev/tty || true
      else
        IFS= read -rsn2 key || true
      fi
      case "${key}" in
        "[A") (( idx = (idx-1+${#items[@]}) % ${#items[@]} )) ;;
        "[B") (( idx = (idx+1) % ${#items[@]} )) ;;
      esac
    elif [[ "${key}" == $'\n' || "${key}" == $'\r' ]]; then
      break
    fi
  done
  tput cnorm 2>/dev/null || true
  echo $((idx+1))
}

# Helper functions for input/validation and workflow
validate_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    if [[ "$o" =~ ^0[0-9]+$ ]]; then return 1; fi
    (( o>=0 && o<=255 )) || return 1
  done
  return 0
}

read_line() {
  local prompt="$1"
  local out=""
  if [[ -r /dev/tty ]]; then
    read -r -p "$prompt " out < /dev/tty || true
  else
    read -r -p "$prompt " out || true
  fi
  out=${out//$'\r'/}
  out=${out%$'\n'}
  echo "$out"
}

read_ip() {
  local label="$1"
  local ip=""
  while :; do
    ip=$(read_line "${label} :")
    ip=${ip//[[:space:]]/}
    if validate_ipv4 "$ip"; then
      clear_screen
      echo "$ip"
      return 0
    else
      echo "${label} 형식이 올바르지 않습니다. IPv4 (예: 192.168.0.10), 각 옥텟 0~255, 선행 0 금지" >&2
    fi
  done
}

confirm_yes_no() {
  local prompt="$1"
  local key=""
  while :; do
    if [[ -r /dev/tty ]]; then
      read -r -p "$prompt (Y/N): " key < /dev/tty || true
    else
      read -r -p "$prompt (Y/N): " key || true
    fi
    key=${key//$'\r'/}
    key=${key//[[:space:]]/}
    case "${key^^}" in
      Y|YES) echo "Y"; return 0 ;;
      N|NO)  echo "N"; return 0 ;;
      *) echo "Y 또는 N으로 입력해주세요." ;;
    esac
  done
}

get_base_install_path() {
  if [[ "${DIRECTORY_PATH:-}" == "/opt" ]]; then
    echo "/opt/logpresso"
  else
    echo "/logpresso"
  fi
}

disable_selinux() {
  print_banner "2-1. SELinux 비활성화"
  echo "→ 초기 SELinux 설정 확인 중..."
  
  if [[ -f /etc/selinux/config ]]; then
    local current_selinux
    current_selinux=$(grep "^SELINUX=" /etc/selinux/config | cut -d'=' -f2)
    echo "→ 현재 SELINUX 설정: $current_selinux"
    
    if [[ "$current_selinux" != "disabled" ]]; then
      echo "→ SELINUX=disabled로 변경 중..."
      if command -v sudo >/dev/null 2>&1; then
        sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
      else
        sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
      fi
      echo "→ 변경된 SELINUX 설정: $(grep "^SELINUX=" /etc/selinux/config | cut -d'=' -f2)"
    else
      echo "→ SELINUX가 이미 disabled로 설정되어 있습니다."
    fi
  fi
  
  echo "→ 현재 SELinux 상태 확인 중..."
  local current_enforce
  current_enforce=$(getenforce 2>/dev/null || echo "unknown")
  echo "→ 현재 SELinux 상태: $current_enforce"
  
  if [[ "$current_enforce" == "Enforcing" ]]; then
    echo "→ SELinux를 Permissive로 변경 중..."
    if command -v sudo >/dev/null 2>&1; then
      sudo setenforce 0 || true
    else
      setenforce 0 || true
    fi
    echo "→ 변경된 SELinux 상태: $(getenforce 2>/dev/null || echo "unknown")"
  fi
  
  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

enable_firewall() {
  print_banner "2-3. 방화벽 활성화"
  echo "→ 방화벽 상태 확인 중..."
  
  local firewall_status
  if command -v firewall-cmd >/dev/null 2>&1; then
    firewall_status=$(firewall-cmd --state 2>/dev/null || echo "not running")
  else
    echo "→ FirewallD가 설치되어 있지 않습니다. 설치를 시도합니다..."
    if command -v dnf >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        sudo dnf install -y firewalld || true
      else
        dnf install -y firewalld || true
      fi
    elif command -v yum >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        sudo yum install -y firewalld || true
      else
        yum install -y firewalld || true
      fi
    elif command -v apt-get >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y firewalld || true
      else
        apt-get update && apt-get install -y firewalld || true
      fi
    fi
    
    if command -v systemctl >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        sudo systemctl enable --now firewalld || true
      else
        systemctl enable --now firewalld || true
      fi
      sleep 2
      firewall_status=$(firewall-cmd --state 2>/dev/null || echo "not running")
    fi
  fi
  
  echo "→ 방화벽 상태: $firewall_status"
  
  if [[ "$firewall_status" == "running" ]]; then
    echo "→ 현재 포트 목록 확인 중..."
    firewall-cmd --list-ports || echo "포트 목록을 가져올 수 없습니다."
    
    echo "→ TCP 포트 추가 중..."
    firewall-cmd --permanent --add-port={443,3306,8443,7140,44300,18443,4444,4567,4568}/tcp || echo "TCP 포트 추가 실패"
    
    echo "→ UDP 포트 추가 중..."
    firewall-cmd --permanent --add-port={514,162}/udp || echo "UDP 포트 추가 실패"
    
    echo "→ 방화벽 재적용 중..."
    firewall-cmd --reload || echo "방화벽 재적용 실패"
    
    echo "→ 적용된 포트 목록 확인 중..."
    firewall-cmd --list-ports || echo "포트 목록을 가져올 수 없습니다."
  else
    echo "→ 방화벽이 실행되지 않고 있습니다. 포트 추가를 건너뜁니다."
  fi
  
  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

auto_extract_archives() {
  print_banner "2-5. 설치 파일 압축 해제"
  local base_path
  base_path=$(get_base_install_path)
  
  # mariadb 폴더가 이미 존재하는지 확인
  if [[ -d "$base_path/mariadb" ]]; then
    echo "→ mariadb 폴더가 이미 존재합니다: $base_path/mariadb"
    local ans
    ans=$(confirm_yes_no "기존 mariadb 폴더를 유지하고 다음 단계로 진행할까요?")
    if [[ "$ans" != "Y" ]]; then
      echo "설치가 중단되었습니다."
      exit 1
    fi
    return 0
  fi
  
  echo "→ 압축 파일 검색 중: $base_path"
  
  # 압축 파일 찾기
  local archive_file=""
  local found_files=()
  
  # 일반적인 압축 파일 확장자들
  for ext in tar.gz tgz tar.bz2 tar.xz zip tar; do
    while IFS= read -r -d '' file; do
      found_files+=("$file")
    done < <(find "$base_path" -maxdepth 1 -type f -name "*.$ext" -print0 2>/dev/null)
  done
  
  if (( ${#found_files[@]} == 0 )); then
    echo "→ 압축 파일을 찾지 못했습니다: $base_path"
    echo "→ 지원되는 확장자: tar.gz, tgz, tar.bz2, tar.xz, zip, tar"
    
    # 사용자가 수동으로 파일명 입력
    echo
    echo "수동으로 압축 파일명을 입력하거나 Enter를 눌러 건너뛰세요."
    local manual_file
    manual_file=$(read_line "압축 파일명 (예: mariadb-10.11.13.tar.gz)")
    manual_file=${manual_file//[[:space:]]/}
    
    if [[ -n "$manual_file" ]]; then
      if [[ -f "$base_path/$manual_file" ]]; then
        archive_file="$base_path/$manual_file"
        echo "→ 수동 입력 파일 발견: $archive_file"
      elif [[ -f "$manual_file" ]]; then
        archive_file="$manual_file"
        echo "→ 수동 입력 파일 발견: $archive_file"
      else
        echo "→ 파일을 찾을 수 없습니다: $manual_file"
        local ans
        ans=$(confirm_yes_no "다음 단계로 진행할까요?")
        if [[ "$ans" != "Y" ]]; then
          echo "설치가 중단되었습니다."
          exit 1
        fi
        return 0
      fi
    else
      local ans
      ans=$(confirm_yes_no "다음 단계로 진행할까요?")
      if [[ "$ans" != "Y" ]]; then
        echo "설치가 중단되었습니다."
        exit 1
      fi
      return 0
    fi
  else
    # 발견된 파일이 있는 경우
    if (( ${#found_files[@]} == 1 )); then
      archive_file="${found_files[0]}"
      echo "→ 발견된 압축 파일: $archive_file"
    else
      echo "→ 여러 압축 파일이 발견되었습니다:"
      local i=1
      for file in "${found_files[@]}"; do
        echo "  $i) $(basename "$file")"
        ((i++))
      done
      
      local choice
      while :; do
        choice=$(read_line "사용할 파일 번호를 선택하세요 (1-${#found_files[@]})")
        choice=${choice//[[:space:]]/}
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#found_files[@]} )); then
          archive_file="${found_files[$((choice-1))]}"
          echo "→ 선택된 파일: $archive_file"
          break
        else
          echo "→ 유효한 번호를 입력해주세요 (1-${#found_files[@]})"
        fi
      done
    fi
  fi
  
  if [[ -n "$archive_file" ]]; then
    echo "→ 압축 해제를 위한 확장자 선택"
    echo "  1) tar.gz / tgz"
    echo "  2) tar.bz2"
    echo "  3) tar.xz"
    echo "  4) zip"
    echo "  5) tar"
    echo "  6) 자동 감지"
    
    local ext_choice
    while :; do
      ext_choice=$(read_line "확장자 유형을 선택하세요 (1-6)")
      ext_choice=${ext_choice//[[:space:]]/}
      if [[ "$ext_choice" =~ ^[1-6]$ ]]; then
        break
      else
        echo "→ 유효한 번호를 입력해주세요 (1-6)"
      fi
    done
    
    local filename=$(basename "$archive_file")
    echo "→ 선택된 파일: $filename"
    echo "→ 압축 해제 중..."
    
    case "$ext_choice" in
      1) # tar.gz / tgz
        echo "→ tar.gz/tgz 형식으로 압축 해제 중..."
        tar -xzf "$archive_file" -C "$base_path" || {
          echo "→ tar.gz 압축 해제 실패. 다른 방법 시도 중..."
          tar -xf "$archive_file" -C "$base_path" || echo "→ 모든 방법 실패"
        }
        ;;
      2) # tar.bz2
        echo "→ tar.bz2 형식으로 압축 해제 중..."
        tar -xjf "$archive_file" -C "$base_path" || echo "→ tar.bz2 압축 해제 실패"
        ;;
      3) # tar.xz
        echo "→ tar.xz 형식으로 압축 해제 중..."
        tar -xJf "$archive_file" -C "$base_path" || echo "→ tar.xz 압축 해제 실패"
        ;;
      4) # zip
        echo "→ zip 형식으로 압축 해제 중..."
        unzip -q "$archive_file" -d "$base_path" || echo "→ zip 압축 해제 실패"
        ;;
      5) # tar
        echo "→ tar 형식으로 압축 해제 중..."
        tar -xf "$archive_file" -C "$base_path" || echo "→ tar 압축 해제 실패"
        ;;
      6) # 자동 감지
        echo "→ 자동 감지로 압축 해제 중..."
        local auto_ext="${filename##*.}"
        case "$auto_ext" in
          gz|tgz)
            if [[ "$filename" == *.tar.gz ]] || [[ "$filename" == *.tgz ]]; then
              tar -xzf "$archive_file" -C "$base_path" || echo "→ 자동 감지 tar.gz 실패"
            fi
            ;;
          bz2)
            if [[ "$filename" == *.tar.bz2 ]]; then
              tar -xjf "$archive_file" -C "$base_path" || echo "→ 자동 감지 tar.bz2 실패"
            fi
            ;;
          xz)
            if [[ "$filename" == *.tar.xz ]]; then
              tar -xJf "$archive_file" -C "$base_path" || echo "→ 자동 감지 tar.xz 실패"
            fi
            ;;
          zip)
            unzip -q "$archive_file" -d "$base_path" || echo "→ 자동 감지 zip 실패"
            ;;
          tar)
            tar -xf "$archive_file" -C "$base_path" || echo "→ 자동 감지 tar 실패"
            ;;
          *)
            echo "→ 자동 감지 실패: 지원되지 않는 확장자 $auto_ext"
            ;;
        esac
        ;;
    esac
    
    # 압축 해제 결과 확인
    echo "→ 압축 해제 완료 확인 중..."
    if [[ -d "$base_path/mariadb" ]]; then
      echo "→ mariadb 폴더 발견: $base_path/mariadb"
    else
      echo "→ mariadb 폴더를 찾을 수 없습니다."
      echo "→ 압축 해제가 제대로 되지 않았을 수 있습니다."
    fi
    
    echo "→ 압축 해제 완료: $base_path"
    echo "→ mariadb 폴더 경로: $base_path/mariadb"
  fi
  
  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

extract_archive_file() {
  local archive_file="$1"
  local extract_dir="$2"
  
  if [[ ! -f "$archive_file" ]]; then
    echo "→ 압축 파일을 찾을 수 없습니다: $archive_file"
    return 1
  fi
  
  echo "→ 압축 파일: $archive_file"
  echo "→ 대상 디렉토리: $extract_dir"
  
  # 사용자가 확장자 유형 선택
  echo "→ 압축 해제를 위한 확장자 선택"
  echo "  1) tar.gz / tgz"
  echo "  2) tar.bz2"
  echo "  3) tar.xz"
  echo "  4) zip"
  echo "  5) tar"
  echo "  6) 자동 감지"
  
  local ext_choice
  while :; do
    ext_choice=$(read_line "확장자 유형을 선택하세요 (1-6)")
    ext_choice=${ext_choice//[[:space:]]/}
    if [[ "$ext_choice" =~ ^[1-6]$ ]]; then
      break
    else
      echo "→ 유효한 번호를 입력해주세요 (1-6)"
    fi
  done
  
  local filename=$(basename "$archive_file")
  echo "→ 선택된 파일: $filename"
  echo "→ 압축 해제 중..."
  
  case "$ext_choice" in
    1) # tar.gz / tgz
      echo "→ tar.gz/tgz 형식으로 압축 해제 중..."
      tar -xzf "$archive_file" -C "$extract_dir" || {
        echo "→ tar.gz 압축 해제 실패. 다른 방법 시도 중..."
        tar -xf "$archive_file" -C "$extract_dir" || echo "→ 모든 방법 실패"
      }
      ;;
    2) # tar.bz2
      echo "→ tar.bz2 형식으로 압축 해제 중..."
      tar -xjf "$archive_file" -C "$extract_dir" || echo "→ tar.bz2 압축 해제 실패"
      ;;
    3) # tar.xz
      echo "→ tar.xz 형식으로 압축 해제 중..."
      tar -xJf "$archive_file" -C "$extract_dir" || echo "→ tar.xz 압축 해제 실패"
      ;;
    4) # zip
      echo "→ zip 형식으로 압축 해제 중..."
      unzip -q "$archive_file" -d "$extract_dir" || echo "→ zip 압축 해제 실패"
      ;;
    5) # tar
      echo "→ tar 형식으로 압축 해제 중..."
      tar -xf "$archive_file" -C "$extract_dir" || echo "→ tar 압축 해제 실패"
      ;;
    6) # 자동 감지
      echo "→ 자동 감지로 압축 해제 중..."
      local auto_ext="${filename##*.}"
      case "$auto_ext" in
        gz|tgz)
          if [[ "$filename" == *.tar.gz ]] || [[ "$filename" == *.tgz ]]; then
            tar -xzf "$archive_file" -C "$extract_dir" || echo "→ 자동 감지 tar.gz 실패"
          fi
          ;;
        bz2)
          if [[ "$filename" == *.tar.bz2 ]]; then
            tar -xjf "$archive_file" -C "$extract_dir" || echo "→ 자동 감지 tar.bz2 실패"
          fi
          ;;
        xz)
          if [[ "$filename" == *.tar.xz ]]; then
            tar -xJf "$archive_file" -C "$extract_dir" || echo "→ 자동 감지 tar.xz 실패"
          fi
          ;;
        zip)
          unzip -q "$archive_file" -d "$extract_dir" || echo "→ 자동 감지 zip 실패"
          ;;
        tar)
          tar -xf "$archive_file" -C "$extract_dir" || echo "→ 자동 감지 tar 실패"
          ;;
        *)
          echo "→ 자동 감지 실패: 지원되지 않는 확장자 $auto_ext"
          ;;
      esac
      ;;
  esac
  
  echo "→ 압축 해제 완료: $extract_dir"
}

clear_screen() {
  printf '\033[3J\033[H\033[2J'
  if command -v tput >/dev/null 2>&1; then
    tput clear || true
  fi
}

step_clear() {
  clear_screen
  draw_logo
}

print_kv() {
  local label="$1"; shift
  local value="$*"
  printf "%-12s : %s\n" "$label" "$value"
}

splash_install() {
  clear_screen
  draw_logo
  echo
  printf "시작 준비 중... (%s)\n" "$VERSION"
  print_separator
  local cols bar_width steps delay i fill empty pct
  cols=$(tput cols 2>/dev/null || echo 80)
  bar_width=$(( cols>24 ? cols-24 : 30 ))
  steps=30
  delay=0.2
  for ((i=1; i<=steps; i++)); do
    pct=$(( i*100/steps ))
    fill=$(printf '%*s' "$(( bar_width*pct/100 ))" '' | tr ' ' '=')
    empty=$(printf '%*s' "$(( bar_width - bar_width*pct/100 ))" '' | tr ' ' ' ')
    printf "\r[%s%s] %3d%%" "$fill" "$empty" "$pct"
    sleep "$delay"
  done
  printf "\n"
  sleep 0.2
}

install_rpms_from_extracted() {
  print_banner "2-6. RPM 패키지 설치"
  local base_path
  base_path=$(get_base_install_path)

  # mariadb 폴더로 이동
  local mariadb_dir="$base_path/mariadb"
  if [[ ! -d "$mariadb_dir" ]]; then
    echo "→ mariadb 폴더를 찾을 수 없습니다: $mariadb_dir"
    echo "→ 압축 해제가 제대로 되지 않았을 수 있습니다."
    local ans
    ans=$(confirm_yes_no "다음 단계로 진행할까요?")
    if [[ "$ans" != "Y" ]]; then
      echo "설치가 중단되었습니다."
      exit 1
    fi
    return 0
  fi

  echo "→ mariadb 폴더로 이동: $mariadb_dir"
  cd "$mariadb_dir" || {
    echo "→ mariadb 폴더로 이동할 수 없습니다: $mariadb_dir"
    exit 1
  }

  # RPM 파일 검색
  local -a rpm_files=()
  while IFS= read -r -d '' file; do
    rpm_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name "*.rpm" -print0 2>/dev/null)

  if (( ${#rpm_files[@]} == 0 )); then
    echo "→ 현재 디렉토리에서 RPM 파일을 찾지 못했습니다: $mariadb_dir"
    echo "→ 상위 디렉토리에서 RPM 파일 검색 중..."
    
    # 상위 디렉토리에서 RPM 검색
    while IFS= read -r -d '' file; do
      rpm_files+=("$file")
    done < <(find "$base_path" -type f -name "*.rpm" -print0 2>/dev/null)
    
    if (( ${#rpm_files[@]} == 0 )); then
      echo "→ 설치할 RPM을 찾지 못했습니다: $base_path"
      local ans
      ans=$(confirm_yes_no "다음 단계로 진행할까요?")
      if [[ "$ans" != "Y" ]]; then
        echo "설치가 중단되었습니다."
        exit 1
      fi
      return 0
    fi
    
    echo "→ 발견된 RPM 파일들:"
    for file in "${rpm_files[@]}"; do
      echo "  - $file"
    done
    
    local ans
    ans=$(confirm_yes_no "이 RPM 파일들을 mariadb 폴더로 복사하고 설치할까요?")
    if [[ "$ans" != "Y" ]]; then
      echo "설치가 중단되었습니다."
      exit 1
    fi
    
    # RPM 파일들을 mariadb 폴더로 복사
    for file in "${rpm_files[@]}"; do
      cp "$file" "$mariadb_dir/" || echo "→ 복사 실패: $file"
    done
    
    # 다시 현재 디렉토리의 RPM 파일 검색
    rpm_files=()
    while IFS= read -r -d '' file; do
      rpm_files+=("$file")
    done < <(find . -maxdepth 1 -type f -name "*.rpm" -print0 2>/dev/null)
  fi

  echo "→ 설치할 RPM 파일 수: ${#rpm_files[@]}"
  echo "→ 현재 작업 디렉토리: $(pwd)"
  
  # RPM 설치 실행
  echo "→ RPM 설치 중..."
  if command -v sudo >/dev/null 2>&1; then
    sudo rpm -Uvh ./*.rpm --force --nodeps || echo "→ RPM 설치 실패"
  else
    rpm -Uvh ./*.rpm --force --nodeps || echo "→ RPM 설치 실패"
  fi

  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

configure_mariadb_server() {
  print_banner "6. MariaDB 설정 변경 (UTF-8 설정)"
  local cfg="/etc/my.cnf.d/server.cnf"
  mkdir -p /etc/my.cnf.d

  echo "→ MariaDB 설정 파일 확인 중: $cfg"
  
  # 기존 파일이 있는지 확인
  if [[ -f "$cfg" ]]; then
    echo "→ 기존 설정 파일이 발견되었습니다. UTF-8 설정을 추가합니다."
    
    # [mysqld] 섹션이 있는지 확인
    if grep -q "^\[mysqld\]" "$cfg"; then
      echo "→ [mysqld] 섹션에 UTF-8 설정을 추가합니다."
      
      # character-set-server가 이미 있는지 확인
      if ! grep -q "^character-set-server=utf8" "$cfg"; then
        echo "character-set-server=utf8" >> "$cfg"
        echo "→ character-set-server=utf8 추가됨"
      else
        echo "→ character-set-server=utf8 이미 존재함"
      fi
      
      # skip-character-set-client-handshake가 이미 있는지 확인
      if ! grep -q "^skip-character-set-client-handshake" "$cfg"; then
        echo "skip-character-set-client-handshake" >> "$cfg"
        echo "→ skip-character-set-client-handshake 추가됨"
      else
        echo "→ skip-character-set-client-handshake 이미 존재함"
      fi
      

    else
      echo "→ [mysqld] 섹션이 없습니다. 새로 생성합니다."
      echo "" >> "$cfg"
      echo "[mysqld]" >> "$cfg"
      echo "character-set-server=utf8" >> "$cfg"
      echo "skip-character-set-client-handshake" >> "$cfg"
    fi
  else
    echo "→ 설정 파일이 없습니다. 새로 생성합니다."
    cat > "$cfg" <<CFG
# # These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
# # See the examples of server my.cnf files in /usr/share/mysql/
# # this is read by the standalone daemon and embedded servers
[server]
# this is only for the mysqld standalone daemon
[mysqld]
character-set-server=utf8
skip-character-set-client-handshake
# # * Galera-related settings
# [galera]
# Mandatory settings
#wsrep_on=ON
#wsrep_provider=
#wsrep_cluster_address=
#binlog_format=row
#default_storage_engine=InnoDB
#innodb_autoinc_lock_mode=2
## Allow server to accept connections on all interfaces.
##bind-address=0.0.0.0
## Optional setting
#wsrep_slave_threads=1
#innodb_flush_log_at_trx_commit=0
# this is only for embedded server
[embedded]
# This group is only read by MariaDB servers, not by MySQL.
# If you use the same .cnf file for MySQL and MariaDB,
# you can put MariaDB-only options here
[mariadb]
# This group is only read by MariaDB-10.11 servers.
# If you use the same .cnf file for MariaDB of different versions,
# use this group for options that older servers don't understand
CFG
  fi

  echo "→ 생성된 설정 파일 내용:"
  sed -e 's/^/  /' "$cfg" | cat
  
  echo "→ MariaDB 설정이 완료되었습니다."
  echo "→ 설정 파일: $cfg"
  echo "→ 추가된 설정:"
  echo "→   - character-set-server=utf8"
  echo "→   - skip-character-set-client-handshake"

  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

start_mariadb_service() {
  print_banner "7. MariaDB 서비스 등록 및 실행 확인"
  
  echo "→ MariaDB 서비스 등록 중..."
  if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable mariadb 2>/dev/null || systemctl enable mysqld 2>/dev/null || true
    
    # 기존 서비스 중지
    echo "→ 기존 MariaDB 서비스 중지 중..."
    systemctl stop mariadb 2>/dev/null || systemctl stop mysqld 2>/dev/null || true
    sleep 2
    
    # 새 설정으로 서비스 시작
    echo "→ 새 설정으로 MariaDB 서비스 시작 중..."
    systemctl start mariadb 2>/dev/null || systemctl start mysqld 2>/dev/null || true
    sleep 3
    
    # 서비스 상태 확인
    echo "→ MariaDB 서비스 상태 확인 중..."
    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
      echo "→ MariaDB 서비스가 성공적으로 시작되었습니다."
    else
      echo "→ MariaDB 서비스 시작 실패. 상태 확인 중..."
      systemctl status mariadb 2>/dev/null | tail -n 10 || systemctl status mysqld 2>/dev/null | tail -n 10 || true
    fi
  fi
  
  echo "→ MariaDB 프로세스 확인 중..."
  ps -ef | grep -E "mariadb|mysqld" | grep -v grep || true
  
  # 소켓 파일 확인 (기본 MariaDB 위치)
  local socket_file="/var/lib/mysql/mysql.sock"
  
  echo "→ 소켓 파일 확인: $socket_file"
  if [[ -S "$socket_file" ]]; then
    echo "→ 소켓 파일이 성공적으로 생성되었습니다."
  else
    echo "→ 소켓 파일을 찾을 수 없습니다. 서비스 시작에 문제가 있을 수 있습니다."
    echo "→ MariaDB 서비스가 아직 완전히 시작되지 않았을 수 있습니다."
  fi
  
  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

provision_mariadb_sonar() {
  print_banner "3A-2. Mariadb의 sonar 계정, DB 생성"
  
  echo "→ MariaDB 서비스 상태 확인 중..."
  
  # MariaDB 서비스가 실행 중인지 확인
  local mariadb_running=false
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
      mariadb_running=true
      echo "→ MariaDB 서비스가 실행 중입니다."
    else
      echo "→ MariaDB 서비스가 실행되지 않고 있습니다. 시작을 시도합니다..."
      systemctl start mariadb 2>/dev/null || systemctl start mysqld 2>/dev/null || true
      sleep 3
      if systemctl is-active --quiet mariadb 2>/dev/null || systemctl is-active --quiet mysqld 2>/dev/null; then
        mariadb_running=true
        echo "→ MariaDB 서비스 시작 성공."
      else
        echo "→ MariaDB 서비스 시작 실패."
      fi
    fi
  fi
  
  # 소켓 파일 확인 (수동 설치와 동일하게)
  local socket_file="/var/lib/mysql/mysql.sock"
  
  echo "→ 소켓 파일 확인: $socket_file"
  if [[ -S "$socket_file" ]]; then
    echo "→ 소켓 파일이 존재합니다."
  else
    echo "→ 소켓 파일을 찾을 수 없습니다."
    echo "→ MariaDB 서비스를 재시작합니다..."
    
    # 서비스 재시작
    if command -v systemctl >/dev/null 2>&1; then
      systemctl restart mariadb 2>/dev/null || systemctl restart mysqld 2>/dev/null || true
      sleep 5
      
      # 재시작 후 소켓 파일 재확인
      if [[ -S "$socket_file" ]]; then
        echo "→ 재시작 후 소켓 파일이 생성되었습니다."
      else
        echo "→ 소켓 파일이 여전히 생성되지 않았습니다."
        echo "→ MariaDB 설정에 문제가 있을 수 있습니다."
      fi
    fi
  fi
  
    # MariaDB 연결 테스트
  echo "→ MariaDB 연결 테스트 중..."
  local connection_test=false
  
  # 찾은 소켓 파일로 연결 시도
  if [[ -n "$socket_file" && -S "$socket_file" ]]; then
    echo "→ 소켓 파일을 사용한 연결 시도: $socket_file"
    if MYSQL_PWD="" mysql -u root --socket="$socket_file" -e "SELECT 1;" >/dev/null 2>&1; then
      connection_test=true
      echo "→ 소켓 파일을 통한 MariaDB 연결 성공."
    fi
  fi
  
  # 소켓 파일 연결이 실패한 경우 다른 방법 시도
  if [[ "$connection_test" == false ]]; then
    echo "→ 소켓 파일 연결 실패. 다른 방법 시도 중..."
    
    # 초기 비밀번호 없이 root로 접속 테스트 (기본 소켓)
    if MYSQL_PWD="" mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
      connection_test=true
      echo "→ MariaDB 초기 비밀번호 없이 연결 성공."
    else
      echo "→ 기본 소켓 연결 실패. TCP 연결 시도 중..."
      
      # TCP 연결 시도 (포트 3306)
      if MYSQL_PWD="" mysql -u root -h 127.0.0.1 -P 3306 -e "SELECT 1;" >/dev/null 2>&1; then
        connection_test=true
        echo "→ MariaDB TCP 연결 성공 (127.0.0.1:3306)."
      else
        echo "→ TCP 연결도 실패. MariaDB 서비스 상태를 확인합니다..."
        
        # 서비스 상태 재확인
        if command -v systemctl >/dev/null 2>&1; then
          echo "→ MariaDB 서비스 상태:"
          systemctl status mariadb 2>/dev/null | head -n 10 || systemctl status mysqld 2>/dev/null | head -n 10 || echo "→ 서비스 상태 확인 실패"
        fi
        
        echo "→ 소켓 파일 상태:"
        if [[ -n "$socket_file" ]]; then
          echo "→ 찾은 소켓 파일: $socket_file"
          if [[ -S "$socket_file" ]]; then
            echo "→ 소켓 파일 존재함"
          else
            echo "→ 소켓 파일이 존재하지 않음"
          fi
        else
          echo "→ 소켓 파일을 찾지 못함"
        fi
      fi
    fi
  fi
  
  if [[ "$connection_test" == false ]]; then
    echo "→ MariaDB 연결에 실패했습니다."
    echo "→ MariaDB가 아직 초기화되지 않았거나 설정에 문제가 있을 수 있습니다."
    echo "→ 다음 단계로 진행하시겠습니까? (MariaDB 설정이 완료되지 않을 수 있습니다)"
    local ans
    ans=$(confirm_yes_no "다음 단계로 진행할까요?")
    if [[ "$ans" != "Y" ]]; then
      echo "설치가 중단되었습니다."
      exit 1
    fi
    return 0
  fi
  
  echo "→ sonar 계정 및 데이터베이스 생성 중..."
  local sql_file
  sql_file=$(mktemp)
  cat > "$sql_file" <<'SQL'
use mysql;
set password = password('mariadb1!');
grant all privileges on *.* to 'root'@'%' identified by 'mariadb1!';
flush privileges;
alter USER root@localhost IDENTIFIED VIA mysql_native_password USING password('mariadb1!');
alter user mysql@localhost identified via unix_socket;
create database sonar default character set utf8 collate utf8_general_ci;
show databases;
create user 'sonar' identified by 'mariadb2!';
grant usage on *.* to 'sonar'@localhost identified by 'mariadb2!';
grant all privileges on sonar.* to 'sonar'@'localhost' identified by 'mariadb2!';
grant all privileges on sonar.* to 'sonar'@'%' identified by 'mariadb2!';
flush privileges;
exit
SQL
  
  echo "→ SQL 명령어 실행 중..."
  
  # 초기 비밀번호 없이 root로 접속 시도
  if MYSQL_PWD="" mysql -u root < "$sql_file" 2>/dev/null; then
    echo "→ SQL 명령어가 성공적으로 실행되었습니다."
  else
    echo "→ 초기 비밀번호 없이 접속 실패. 다른 방법 시도 중..."
    
    # TCP 연결로 시도
    if MYSQL_PWD="" mysql -u root -h 127.0.0.1 -P 3306 < "$sql_file" 2>/dev/null; then
      echo "→ TCP 연결로 SQL 명령어 실행 성공."
    else
      echo "→ 모든 연결 방법 실패. 수동으로 실행해야 할 수 있습니다."
      echo "→ 다음 명령어를 MariaDB에 직접 입력하세요:"
      echo "→ mysql -u root -p"
      echo "→ (비밀번호 입력 시 Enter 키만 누르세요)"
      echo "→ 그리고 아래 SQL 명령어들을 순서대로 실행하세요:"
      cat "$sql_file"
    fi
  fi
  
  rm -f "$sql_file"
  echo "→ sonar 계정 및 데이터베이스 생성 완료."
  
  local ans
  ans=$(confirm_yes_no "다음 단계로 진행할까요?")
  if [[ "$ans" != "Y" ]]; then
    echo "설치가 중단되었습니다."
    exit 1
  fi
}

install_mariadb() {
  print_banner "2-4. MariaDB 설치"
  progress_bar "MariaDB 설치 준비 중" 30 0.04
  local base_path
  base_path=$(get_base_install_path)
  mkdir -p "$base_path" || true

  echo "선택된 유형: ${MARIADB_INSTALL_LABEL:-미선택}"
  if [[ "${MARIADB_INSTALL_MODE:-}" == "manual" ]]; then
    echo "→ 패키지 설치(dnf/yum)"
    if command -v dnf >/dev/null 2>&1; then
      dnf -y install MariaDB-server MariaDB-client || true
    elif command -v yum >/dev/null 2>&1; then
      yum -y install MariaDB-server MariaDB-client || true
    else
      echo "dnf/yum이 없어 설치를 진행할 수 없습니다." >&2
      return 0
    fi

    echo "→ 서비스 활성화/시작"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable mariadb 2>/dev/null || systemctl enable mysqld 2>/dev/null || true
      systemctl start mariadb 2>/dev/null || systemctl start mysqld 2>/dev/null || true
      systemctl status mariadb 2>/dev/null | tail -n 5 || systemctl status mysqld 2>/dev/null | tail -n 5 || true
    fi

  elif [[ "${MARIADB_INSTALL_MODE:-}" == "rhel" ]]; then
    if [[ "${MARIADB_RHEL_VERSION:-}" == "8" ]]; then
      echo "→ RHEL 8: yum으로 설치"
      yum -y install MariaDB-server MariaDB-client || true
    elif [[ "${MARIADB_RHEL_VERSION:-}" == "9" ]]; then
      echo "→ RHEL 9: dnf으로 설치"
      dnf -y install MariaDB-server MariaDB-client || true
    else
      echo "RHEL ${MARIADB_RHEL_VERSION:-?} 환경은 준비 중입니다."
      return 0
    fi

    echo "→ 서비스 활성화/시작"
    if command -v systemctl >/dev/null 2>&1; then
      systemctl enable mariadb 2>/dev/null || systemctl enable mysqld 2>/dev/null || true
      systemctl start mariadb 2>/dev/null || systemctl start mysqld 2>/dev/null || true
      systemctl status mariadb 2>/dev/null | tail -n 5 || systemctl status mysqld 2>/dev/null | tail -n 5 || true
    fi

  else
    echo "CentOS 환경은 준비 중입니다."
  fi
}

ensure_unzip() {
  if command -v unzip >/dev/null 2>&1; then return 0; fi
  if command -v dnf >/dev/null 2>&1; then
    dnf -y install unzip || true
  elif command -v yum >/dev/null 2>&1; then
    yum -y install unzip || true
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update -y || true
    apt-get install -y unzip || true
  fi
}

run_workflow() {
  print_banner "🚀 워크플로우 시작"
  if [[ "$SERVER_MODE" == "single" ]]; then
    echo "단일 서버(Active) 설치를 진행합니다."
    echo "- Active IP: $ACTIVE_IP"
  else
    echo "이중화 서버 설치를 진행합니다."
    echo "- Active IP: $ACTIVE_IP"
    echo "- Standby IP: $STANDBY_IP"
  fi

  step_clear; disable_selinux
  step_clear; enable_firewall

  step_clear
  if [[ -n "${DIRECTORY_PATH:-}" ]]; then
    if [[ -d "$DIRECTORY_PATH" ]]; then
      echo "디렉토리 존재: $DIRECTORY_PATH"
    else
      if mkdir -p "$DIRECTORY_PATH" 2>/dev/null; then
        echo "디렉토리 생성: $DIRECTORY_PATH"
      else
        echo "디렉토리 생성 실패: $DIRECTORY_PATH (권한 필요?)" >&2
      fi
    fi
    local base_path
    base_path=$(get_base_install_path)
    if [[ ! -d "$base_path" ]]; then
      mkdir -p "$base_path"; echo "디렉토리 생성: $base_path"
    else
      echo "디렉토리 존재: $base_path"
    fi
    mkdir -p "/data/logpresso-data"; echo "디렉토리 생성: /data/logpresso-data"
    if [[ ! -d "$base_path/log" ]]; then
      mkdir -p "$base_path/log"; echo "디렉토리 생성: $base_path/log"
    else
      echo "디렉토리 존재: $base_path/log"
    fi
  fi

  step_clear; install_mariadb
  step_clear; auto_extract_archives
  step_clear; install_rpms_from_extracted
  step_clear; configure_mariadb_server
  step_clear; start_mariadb_service
  step_clear; provision_mariadb_sonar
}

# Run
splash_install

# 0. 작업 선택
step_clear
show_menu "0. 작업 선택" "패키지 설치" "패키지 업데이트 (준비중)"
op_choice=$(read_choice_framed 2 "번호를 입력하세요")
case "$op_choice" in
  1) OPERATION_MODE="install" ;;
  2) OPERATION_MODE="update" ;;
  *) OPERATION_MODE="install" ;;
 esac
if [[ "$OPERATION_MODE" == "update" ]]; then
  step_clear
  print_banner "패키지 업데이트 (준비중)"
  progress_bar "업데이트 준비 중" 30 0.04
  echo "이 기능은 준비 중입니다. 곧 지원될 예정입니다."
  exit 0
fi
clear_screen

# Step 1-3 with basic back navigation
while :; do
# 1. 설치 유형
  step_clear
  show_menu_with_back "1. 설치 유형" "분석" "수집" "전달"
  choice=$(read_choice_zero 3 "❯ 입력")
  if [[ "$choice" == 0 ]]; then
    # back to operation select
    step_clear
    show_menu "0. 작업 선택" "패키지 설치" "패키지 업데이트 (준비중)"
    op_choice=$(read_choice_framed 2 "번호를 입력하세요")
    [[ "$op_choice" == 2 ]] && { print_banner "패키지 업데이트 (준비중)"; exit 0; }
    continue
  fi
case "$choice" in
    1) SELECTED_ROLE="analysis"; SELECTED_ROLE_LABEL="분석" ;;
    2) SELECTED_ROLE="collector"; SELECTED_ROLE_LABEL="수집" ;;
    3) SELECTED_ROLE="forwarder"; SELECTED_ROLE_LABEL="전달" ;;
    *) SELECTED_ROLE="analysis"; SELECTED_ROLE_LABEL="분석" ;;
   esac

  # 2. 서버 유형 (with back to step 1)
  while :; do
    step_clear
    show_menu_with_back "2. 서버 유형" "단일 서버" "이중화 서버"
    choice2=$(read_choice_zero 2 "❯ 입력")
    if [[ "$choice2" == 0 ]]; then
      # back to step 1
      continue 2
    fi
    case "$choice2" in
      1) SERVER_MODE="single"; SERVER_MODE_LABEL="단일 서버" ;;
      2) SERVER_MODE="dual";   SERVER_MODE_LABEL="이중화 서버" ;;
      *) SERVER_MODE="single"; SERVER_MODE_LABEL="단일 서버" ;;
     esac
    break
  done

  # 3. 세부 유형 (with back to step 2)
  while :; do
    if [[ "$SERVER_MODE" == "single" ]]; then
      NODE_ROLE="active"; NODE_ROLE_LABEL="Active"
      break
    fi
    step_clear
    show_menu_with_back "3. 세부 유형" "Active" "Standby"
    choice3=$(read_choice_zero 2 "❯ 입력")
    if [[ "$choice3" == 0 ]]; then
      # back to step 2 loop
      continue 2
    fi
    case "$choice3" in
      1) NODE_ROLE="active";  NODE_ROLE_LABEL="Active" ;;
      2) NODE_ROLE="standby"; NODE_ROLE_LABEL="Standby" ;;
      *) NODE_ROLE="active";  NODE_ROLE_LABEL="Active" ;;
    esac
    break
  done
  break
done

# 4. IP 입력
step_clear
print_banner "4. IP 입력"
if [[ "$SERVER_MODE" == "single" ]]; then
  ACTIVE_IP=$(read_ip "Active IP")
  STANDBY_IP=""
else
  ACTIVE_IP=$(read_ip "Active IP")
  step_clear
  print_banner "4. IP 입력"
  STANDBY_IP=$(read_ip "Standby IP")
fi

# 5. 디렉토리 생성 (with back to step 4)
while :; do
  step_clear
  show_menu_with_back "5. 디렉토리 생성" "/opt" "/logpresso"
  choice_dir=$(read_choice_zero 2 "❯ 입력")
  if [[ "$choice_dir" == 0 ]]; then
    # go back to step 4 (IP 입력)
    step_clear
    print_banner "4. IP 입력"
    if [[ "$SERVER_MODE" == "single" ]]; then
      ACTIVE_IP=$(read_ip "Active IP")
      STANDBY_IP=""
    else
      ACTIVE_IP=$(read_ip "Active IP")
      step_clear
      print_banner "4. IP 입력"
      STANDBY_IP=$(read_ip "Standby IP")
    fi
    continue
  fi
  case "$choice_dir" in
    1) DIRECTORY_PATH="/opt"; DIRECTORY_LABEL="/opt" ;;
    2) DIRECTORY_PATH="/logpresso"; DIRECTORY_LABEL="/logpresso" ;;
    *) DIRECTORY_PATH="/logpresso"; DIRECTORY_LABEL="/logpresso" ;;
   esac
  break
done
clear_screen

# 6. MariaDB 설치 환경 (with back to step 5)
while :; do
  step_clear
  show_menu_with_back "6. MariaDB 설치 환경" "CentOS" "Red Hat Enterprise Linux" "수동 업로드"
  choice_db=$(read_choice_zero 3 "❯ 입력")
  if [[ "$choice_db" == 0 ]]; then
    # back to directory selection
    while :; do
      step_clear
      show_menu_with_back "5. 디렉토리 생성" "/opt" "/logpresso"
      choice_dir=$(read_choice_zero 2 "❯ 입력")
      if [[ "$choice_dir" == 0 ]]; then break; fi
      case "$choice_dir" in
        1) DIRECTORY_PATH="/opt"; DIRECTORY_LABEL="/opt" ;;
        2) DIRECTORY_PATH="/logpresso"; DIRECTORY_LABEL="/logpresso" ;;
        *) DIRECTORY_PATH="/logpresso"; DIRECTORY_LABEL="/logpresso" ;;
       esac
      break
    done
    continue
  fi
  case "$choice_db" in
    1)
      MARIADB_INSTALL_MODE="centos"; MARIADB_INSTALL_LABEL="CentOS (준비중)"
      echo "해당 패키지는 개발 중입니다. 다른 유형을 선택해주세요."; sleep 1.2
      ;;
    2)
      MARIADB_INSTALL_MODE="rhel"; MARIADB_INSTALL_LABEL="Red Hat Enterprise Linux"
      # RHEL version with back
      while :; do
        step_clear
        show_menu_with_back "6-1. RHEL 버전" "레드햇 엔터프라이즈 리눅스 7" "레드햇 엔터프라이즈 리눅스 8" "레드햇 엔터프라이즈 리눅스 9"
        choice_rhel=$(read_choice_zero 3 "❯ 입력")
        if [[ "$choice_rhel" == 0 ]]; then continue 2; fi
        case "$choice_rhel" in
          1) MARIADB_RHEL_VERSION="7"; MARIADB_RHEL_LABEL="레드햇 엔터프라이즈 리눅스 7" ;;
          2) MARIADB_RHEL_VERSION="8"; MARIADB_RHEL_LABEL="레드햇 엔터프라이즈 리눅스 8" ;;
          3) MARIADB_RHEL_VERSION="9"; MARIADB_RHEL_LABEL="레드햇 엔터프라이즈 리눅스 9" ;;
          *) MARIADB_RHEL_VERSION="8"; MARIADB_RHEL_LABEL="레드햇 엔터프라이즈 리눅스 8" ;;
        esac
        break
      done
      if [[ "$MARIADB_RHEL_VERSION" == "8" || "$MARIADB_RHEL_VERSION" == "9" ]]; then
        while :; do
          step_clear
          show_menu_with_back "6-2. MariaDB 버전 (RHEL ${MARIADB_RHEL_VERSION})" "12.1" "12.0" "11.8" "11.4" "10.11"
          choice_ver=$(read_choice_zero 5 "❯ 입력")
          if [[ "$choice_ver" == 0 ]]; then continue 2; fi
          case "$choice_ver" in
            1) MARIADB_VERSION="12.1" ;;
            2) MARIADB_VERSION="12.0" ;;
            3) MARIADB_VERSION="11.8" ;;
            4) MARIADB_VERSION="11.4" ;;
            5) MARIADB_VERSION="10.11" ;;
            *) MARIADB_VERSION="12.1" ;;
          esac
          MARIADB_VERSION_LABEL="$MARIADB_VERSION"
          break
        done
      fi
      break
      ;;
    3)
      MARIADB_INSTALL_MODE="manual"; MARIADB_INSTALL_LABEL="수동 업로드"
      base_path=$(get_base_install_path)
      if [[ ! -d "$base_path" ]]; then
        mkdir -p "$base_path"; echo "디렉토리 생성: $base_path"
      else
        echo "디렉토리 존재: $base_path"
      fi
      mkdir -p "/data/logpresso-data"; echo "디렉토리 생성: /data/logpresso-data"
      mkdir -p "$base_path/log"; echo "디렉토리 생성: $base_path/log"
      echo "예시: Mariadb-10.11.13.tar.gz (확장자 포함)"
      echo "업로드 경로: $base_path"
      MARIADB_MANUAL_FILENAME=$(read_line "업로드할 파일 명칭 입력")
      MARIADB_MANUAL_FILENAME=${MARIADB_MANUAL_FILENAME//[[:space:]]/}
      step_clear
      uploaded=$(confirm_yes_no "파일 업로드가 완료되었나요?")
      if [[ "$uploaded" == "Y" ]]; then
        candidate=""
        if [[ -f "$MARIADB_MANUAL_FILENAME" ]]; then
          candidate="$MARIADB_MANUAL_FILENAME"
        elif [[ -f "$base_path/$MARIADB_MANUAL_FILENAME" ]]; then
          candidate="$base_path/$MARIADB_MANUAL_FILENAME"
        elif [[ -f "./$MARIADB_MANUAL_FILENAME" ]]; then
          candidate="./$MARIADB_MANUAL_FILENAME"
        fi
        if [[ -n "$candidate" ]]; then
          echo "소스 파일: $candidate"
          extract_archive_file "$candidate" "$base_path"
          MARIADB_MANUAL_FILE_PATH="$candidate"
        else
          echo "파일을 찾지 못했습니다: $MARIADB_MANUAL_FILENAME"
        fi
      fi
      break ;;
    *) ;;
  esac
  [[ -n "${MARIADB_INSTALL_MODE:-}" ]] && break
  sleep 0.3
  clear_screen
done
clear_screen

# Export selections for chaining
INSTALL_SERVER_TYPE="$SERVER_MODE"
export SELECTED_ROLE SELECTED_ROLE_LABEL SERVER_MODE SERVER_MODE_LABEL NODE_ROLE NODE_ROLE_LABEL INSTALL_SERVER_TYPE ACTIVE_IP STANDBY_IP DIRECTORY_PATH DIRECTORY_LABEL MARIADB_INSTALL_MODE MARIADB_INSTALL_LABEL MARIADB_RHEL_VERSION MARIADB_RHEL_LABEL MARIADB_VERSION MARIADB_VERSION_LABEL MARIADB_MANUAL_FILENAME MARIADB_MANUAL_FILE_PATH

# Summary / Final Confirmation
step_clear
print_banner "최종 확인"
echo "-"
echo "설치 유형 : ${SELECTED_ROLE_LABEL}"
echo "서버 유형 : ${SERVER_MODE_LABEL}"
echo "세부 유형 : ${NODE_ROLE_LABEL}"
echo "설치 디렉토리 : ${DIRECTORY_PATH}"
if [[ "$SERVER_MODE" == single ]]; then
  echo "Active IP : ${ACTIVE_IP}"
else
  echo "Active IP : ${ACTIVE_IP}"
  echo "Standby IP : ${STANDBY_IP}"
fi
if [[ "${MARIADB_INSTALL_MODE:-}" == "rhel" ]]; then
  echo "MariaDB 설치 : ${MARIADB_INSTALL_LABEL} (${MARIADB_RHEL_LABEL})"
  [[ -n "${MARIADB_VERSION:-}" ]] && echo "MariaDB 버전 : ${MARIADB_VERSION}"
else
  echo "MariaDB 설치 : ${MARIADB_INSTALL_LABEL:-미선택}"
  [[ -n "${MARIADB_MANUAL_FILENAME:-}" ]] && echo "업로드 파일 : ${MARIADB_MANUAL_FILENAME}"
fi
print_separator 

ans=$(confirm_yes_no "설정을 진행할까요?")
if [[ "$ans" == "Y" ]]; then
  print_banner "✅ 설정 확인됨"
  run_workflow
else
  echo "설치가 취소되었습니다."
  exit 1
fi