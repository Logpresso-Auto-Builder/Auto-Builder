#!/bin/bash

# =============================================
# Logpresso Auto Builder Script
# =============================================
# Description: 자동화된 Logpresso 시스템 설치 스크립트
# Version: 1.0
# Author: Auto Builder 
# =============================================

# =============================================
# SECTION 1: UI & DISPLAY FUNCTIONS
# =============================================

# 종료 처리 함수
cleanup_and_exit() {
  echo ""
  show_info "프로그램을 종료합니다..."
  show_info "임시 파일들을 정리 중..."
  # 임시 파일 정리
  rm -f /tmp/cookie /tmp/intermezzo.html 2>/dev/null
  exit 0
}

# 시그널 핸들러 설정
trap cleanup_and_exit SIGINT SIGTERM

# 실패 처리 함수
handle_failure() {
  local step_name="$1"
  local error_message="$2"
  local retry_function="$3"
  
  echo ""
  show_error "❌ $step_name 실패: $error_message"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "                           ⚠️  오류 발생"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "1. 🔄 다시 시도"
  echo "2. ⏭️  다음 단계로 진행"
  echo "3. 🚪 프로그램 종료"
  echo ""
  
  while true; do
    read -p "🎯 선택하세요 (1-3): " choice
    case $choice in
      1) 
        show_info "다시 시도합니다..."
        if [[ -n "$retry_function" ]]; then
          eval "$retry_function"
        fi
        return 1  # 재시도
        ;;
      2) 
        show_warning "다음 단계로 진행합니다. (오류 무시)"
        return 0  # 계속 진행
        ;;
      3) 
        cleanup_and_exit
        ;;
      *) 
        show_error "1-3 중 선택해주세요."
        ;;
    esac
  done
}

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

clear_screen_and_logo() {
  clear
  draw_logo
}

show_progress() {
  local message="$1"
  echo "🔄 $message"
}

show_success() {
  local message="$1"
  echo "✅ $message"
}

show_error() {
  local message="$1"
  echo "❌ $message"
}

show_info() {
  local message="$1"
  echo "ℹ️  $message"
}

show_warning() {
  local message="$1"
  echo "⚠️  $message"
}

# =============================================
# SECTION 2: SYSTEM PREPARATION FUNCTIONS
# =============================================

install_pip_and_gdown() {
  show_info "시스템 의존성 패키지 확인 중..."
  
  if ! command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
    show_warning "pip 명령어가 없습니다. 패키지 설치를 시도합니다..."
    if command -v yum &>/dev/null; then
      show_progress "yum을 사용하여 python3-pip 설치 중..."
      sudo yum install -y python3-pip
    elif command -v dnf &>/dev/null; then
      show_progress "dnf를 사용하여 python3-pip 설치 중..."
      sudo dnf install -y python3-pip
    elif command -v apt &>/dev/null; then
      show_progress "apt를 사용하여 python3-pip 설치 중..."
      sudo apt update
      sudo apt install -y python3-pip
    else
      show_error "지원되는 패키지 관리자를 찾을 수 없습니다. pip 수동 설치가 필요합니다."
      exit 1
    fi
  fi

  if command -v pip3 &>/dev/null; then
    pipcmd="pip3"
  else
    pipcmd="pip"
  fi

  show_progress "pip 업그레이드 중..."
  sudo "$pipcmd" install --upgrade pip setuptools wheel

  if ! command -v gdown &>/dev/null; then
    show_progress "gdown 설치 중..."
    sudo "$pipcmd" install --upgrade gdown
    if ! command -v gdown &>/dev/null; then
      show_error "gdown 설치에 실패했습니다."
      exit 1
    fi
  fi
  
  show_success "시스템 의존성 패키지 설치 완료"
}

curl_download_gdrive() {
  local fileid=$1
  local filename=$2
  show_progress "curl을 사용하여 구글 드라이브에서 다운로드 중..."
  
  curl -c /tmp/cookie "https://drive.google.com/uc?export=download&id=${fileid}" > /tmp/intermezzo.html 2>/dev/null

  local confirm=$(grep -o 'confirm=[^&]*' /tmp/intermezzo.html | head -1 | cut -d= -f2)

  if [ -n "$confirm" ]; then
    curl -Lb /tmp/cookie "https://drive.google.com/uc?export=download&confirm=${confirm}&id=${fileid}" -o "${filename}"
  else
    curl -Lb /tmp/cookie "https://drive.google.com/uc?export=download&id=${fileid}" -o "${filename}"
  fi

  if [ $? -eq 0 ] && [ -f "$filename" ]; then
    show_success "curl 다운로드 성공: $filename"
    return 0
  else
    show_error "curl 다운로드 실패"
    return 1
  fi
}

# =============================================
# SECTION 3: VALIDATION FUNCTIONS
# =============================================

validate_ip() {
  local ip=$1
  local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

  if [[ ! $ip =~ $regex ]]; then
    return 1
  fi

  IFS='.' read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    if ((octet < 0 || octet > 255)); then
      return 1
    fi
    if [[ $octet =~ ^0[0-9]+ ]]; then
      return 1
    fi
  done
  return 0
}

input_ip_conditionally() {
  local label=$1
  local varname=$2
  local current_val="${!varname}"

  if [[ -n "$current_val" ]]; then
    show_info "$label IP 이미 존재: $current_val (재입력 불필요)"
  else
    while true; do
      read -p "📝 $label IP를 입력하세요 (예: 192.168.0.1): " input_ip
      if validate_ip "$input_ip"; then
        show_success "유효한 IP입니다: $input_ip"
        eval "$varname='$input_ip'"
        break
      else
        show_error "잘못된 IP 형식입니다. 다시 입력해주세요."
      fi
    done
  fi
}

# =============================================
# SECTION 4: USER INTERFACE FUNCTIONS
# =============================================

select_install_type() {
  while true; do
    clear_screen_and_logo
    echo "────────────────────────────────────────────────────────────────"
    echo "                    📋 설치 유형 선택"
    echo "────────────────────────────────────────────────────────────────"
    echo "  0. 🚪 프로그램 종료"
    echo "  1. 🔍 분석 서버"
    echo "  2. 📊 수집 서버"
    echo "  3. 📤 전달 서버"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    read -p "🎯 설치 유형을 숫자로 선택하세요 (0~3): " choice
    case $choice in
      0) 
        cleanup_and_exit
        ;;
      1) 
        type="분석"
        show_success "분석 서버 설치를 선택하셨습니다."
        break 
        ;;
      2) 
        type="수집"
        show_success "수집 서버 설치를 선택하셨습니다."
        break 
        ;;
      3) 
        type="전달"
        show_success "전달 서버 설치를 선택하셨습니다."
        break 
        ;;
      *) 
        show_error "0~3 중 숫자만 입력하세요." 
        sleep 2 
        ;;
    esac
  done
}

select_subtype() {
  while true; do
    clear_screen_and_logo
    echo "────────────────────────────────────────────────────────────────"
    echo "                   🔧 세부 유형 선택"
    echo "────────────────────────────────────────────────────────────────"
    echo "  0. ⬅️  뒤로가기"
    echo "  1. 🖥️  단일 서버"
    echo "  2. 🔄 이중화 서버"
    echo "  9. 🚪 프로그램 종료"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    read -p "🎯 세부 유형을 숫자로 선택하세요 (0-2, 9): " detail_choice
    case $detail_choice in
      0) 
        select_install_type
        select_subtype
        break 
        ;;
      1) 
        subtype="단일 서버"
        show_success "단일 서버 설치를 선택하셨습니다."
        break 
        ;;
      2) 
        subtype="이중화 서버"
        show_success "이중화 서버 설치를 선택하셨습니다."
        break 
        ;;
      9)
        cleanup_and_exit
        ;;
      *) 
        show_error "0-2 또는 9 중 숫자만 입력하세요." 
        sleep 2 
        ;;
    esac
  done
}

select_ha_status() {
  while true; do
    clear_screen_and_logo
    echo "────────────────────────────────────────────────────────────────"
    echo "                  🔄 이중화 상태 선택"
    echo "────────────────────────────────────────────────────────────────"
    echo "  0. ⬅️  뒤로가기"
    echo "  1. 🟢 Active (주 서버)"
    echo "  2. 🟡 Standby (대기 서버)"
    echo "  9. 🚪 프로그램 종료"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    read -p "🎯 이중화 상태를 숫자로 선택하세요 (0-2, 9): " hs_choice
    case $hs_choice in
      0) 
        select_subtype
        select_ha_status
        break 
        ;;
      1)
        status="Active"
        ACTIVE_IP="$ip"
        show_success "Active 서버로 설정되었습니다."
        input_ip_conditionally "Standby" STANDBY_IP
        break
        ;;
      2)
        status="Standby"
        STANDBY_IP="$ip"
        show_success "Standby 서버로 설정되었습니다."
        input_ip_conditionally "Active" ACTIVE_IP
        break
        ;;
      9)
        cleanup_and_exit
        ;;
      *)
        show_error "0-2 또는 9 중 숫자만 입력해주세요." 
        sleep 2 
        ;;
    esac
  done
}

select_directory() {
  while true; do
    clear_screen_and_logo
    echo "────────────────────────────────────────────────────────────────"
    echo "                  📁 파일 디렉토리 선택"
    echo "────────────────────────────────────────────────────────────────"
    echo "  0. ⬅️  뒤로가기"
    echo "  1. 📂 /opt/logpresso (권장)"
    echo "  2. 📂 /logpresso"
    echo "  9. 🚪 프로그램 종료"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    read -p "🎯 디렉토리를 숫자로 선택하세요 (0-2, 9): " dir_choice
    case $dir_choice in
      0) 
        select_ha_status
        select_directory
        break 
        ;;
      1) 
        base_dir="/opt/logpresso"
        show_success "설치 디렉토리: $base_dir"
        break 
        ;;
      2) 
        base_dir="/logpresso"
        show_success "설치 디렉토리: $base_dir"
        break 
        ;;
      9)
        cleanup_and_exit
        ;;
      *) 
        show_error "0-2 또는 9 중 숫자만 입력하세요." 
        sleep 2 
        ;;
    esac
  done
}

select_mariadb_install_method() {
  while true; do
    clear_screen_and_logo
    echo "────────────────────────────────────────────────────────────────"
    echo "                🗄️  MariaDB 설치 방법 선택"
    echo "────────────────────────────────────────────────────────────────"
    echo "  0. ⬅️  뒤로가기"
    echo "  1. 🌐 Mariadb-10.11.13 (권장)"
    echo "  2. 📁 수동 업로드"
    echo "  9. 🚪 프로그램 종료"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    read -p "🎯 설치 방법을 숫자로 선택하세요 (0-2, 9): " mdb_choice
    case $mdb_choice in
      0) 
        select_directory
        select_mariadb_install_method
        break 
        ;;
      1|2) 
        if [[ "$mdb_choice" == "1" ]]; then
          show_success "다운로드 방식으로 MariaDB를 설치합니다."
        else
          show_success "수동 업로드 방식으로 MariaDB를 설치합니다."
        fi
        break 
        ;;
      9)
        cleanup_and_exit
        ;;
      *) 
        show_error "0-2 또는 9 중 숫자만 입력하세요." 
        sleep 2 
        ;;
    esac
  done
}

# =============================================
# SECTION 5: MARIADB INSTALLATION FUNCTIONS
# =============================================

install_mariadb() {
  local mariadb_dir="$base_dir"
  
  clear_screen_and_logo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "                           🗄️  MariaDB 설치 및 설정"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  show_progress "MariaDB 설치 디렉토리로 이동: $mariadb_dir"
  cd "$mariadb_dir" || { 
    handle_failure "MariaDB 디렉토리 이동" "디렉토리 이동 실패"
    return 1
  }
  
  # MariaDB 압축 해제된 디렉토리 찾기
  mariadb_extracted_dir=$(find . -maxdepth 1 -type d -name "*mariadb*" -o -name "*MariaDB*" | head -1)
  if [[ -z "$mariadb_extracted_dir" ]]; then
    handle_failure "MariaDB 디렉토리 검색" "MariaDB 압축 해제된 디렉토리를 찾을 수 없습니다."
    return 1
  fi
  
  show_success "MariaDB 디렉토리 발견: $mariadb_extracted_dir"
  cd "$mariadb_extracted_dir" || { 
    handle_failure "MariaDB 디렉토리 이동" "MariaDB 디렉토리 이동 실패"
    return 1
  }
  
  show_progress "RPM 패키지 설치 중..."
  sudo rpm -Uvh *.rpm --force --nodeps
  if [[ $? -ne 0 ]]; then
    handle_failure "RPM 패키지 설치" "RPM 설치 실패"
    return 1
  fi
  
  show_progress "MariaDB 설정 파일 생성 중..."
  sudo mkdir -p /etc/my.cnf.d
  
  # 기존 파일이 있으면 백업
  if [[ -f /etc/my.cnf.d/server.cnf ]]; then
    sudo cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.backup
    show_info "기존 설정 파일 백업: /etc/my.cnf.d/server.cnf.backup"
  fi
  
  # [mysqld] 섹션에 설정 추가 (기존 내용 유지)
  if ! grep -q "^\[mysqld\]" /etc/my.cnf.d/server.cnf; then
    sudo tee -a /etc/my.cnf.d/server.cnf > /dev/null <<EOF

[mysqld]
character-set-server=utf8
skip-character-set-client-handshake
#port=3306 (변경시에 사용)
EOF
  else
    show_info "[mysqld] 섹션이 존재합니다. 필요한 설정을 추가합니다."
    # [mysqld] 섹션에 필요한 설정들이 있는지 확인하고 없으면 추가
    if ! grep -q "character-set-server=utf8" /etc/my.cnf.d/server.cnf; then
      sudo sed -i '/^\[mysqld\]/a character-set-server=utf8' /etc/my.cnf.d/server.cnf
    fi
    if ! grep -q "skip-character-set-client-handshake" /etc/my.cnf.d/server.cnf; then
      sudo sed -i '/^\[mysqld\]/a skip-character-set-client-handshake' /etc/my.cnf.d/server.cnf
    fi
  fi
  
  show_progress "MariaDB 서비스 활성화 중..."
  sudo systemctl enable mariadb
  
  show_progress "MariaDB 서비스 시작 중..."
  
  # MariaDB 초기화 (첫 실행 시)
  if [[ ! -d /var/lib/mysql/mysql ]]; then
    show_progress "MariaDB 데이터베이스 초기화 중..."
    sudo mysql_install_db --user=mysql --datadir=/var/lib/mysql
    if [[ $? -ne 0 ]]; then
      handle_failure "MariaDB 초기화" "MariaDB 데이터베이스 초기화 실패"
      return 1
    fi
  fi
  
  # 서비스 시작
  sudo systemctl start mariadb
  
  # 서비스 시작 확인
  if ! sudo systemctl is-active --quiet mariadb; then
    show_error "MariaDB 서비스 시작 실패"
    show_info "서비스 상태 확인: sudo systemctl status mariadb"
    show_info "로그 확인: sudo journalctl -xeu mariadb.service"
    
    # 설정 파일 권한 확인
    show_progress "설정 파일 권한 확인 중..."
    sudo chown mysql:mysql /etc/my.cnf.d/server.cnf
    sudo chmod 644 /etc/my.cnf.d/server.cnf
    
    # 다시 서비스 시작 시도
    show_progress "MariaDB 서비스 재시작 시도 중..."
    sudo systemctl start mariadb
    
    if ! sudo systemctl is-active --quiet mariadb; then
      handle_failure "MariaDB 서비스 시작" "MariaDB 서비스 시작 실패 (재시도 후)"
      return 1
    fi
  fi
  
  show_success "MariaDB 서비스 시작 완료"
  show_progress "MariaDB 프로세스 확인 중..."
  ps -ef | grep mysql
  
  # Active 서버에서만 MariaDB 비밀번호 설정 진행
  if [[ "$status" == "Active" ]]; then
    show_progress "MariaDB 기본 비밀번호 설정 중... (Active 서버)"
    # 서비스가 완전히 시작될 때까지 대기
    sleep 5
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                           🔑 MariaDB 비밀번호 설정"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    show_info "MariaDB에 접속하여 비밀번호를 설정합니다."
    show_info "초기 비밀번호가 없는 경우 Enter를 누르세요."
    echo ""
    
    # 사용자에게 MariaDB 접속 안내
    read -p "MariaDB 접속을 위해 Enter를 누르세요... " -r
    
    # MariaDB 접속 및 비밀번호 설정
    mysql -uroot -p <<EOF
use mysql;
set password = password('mariadb1!');
grant all privileges on *.* to 'root'@'%' identified by 'mariadb1!';
flush privileges;
alter USER root@localhost IDENTIFIED VIA mysql_native_password USING password('mariadb1!');
alter user mysql@localhost identified via unix_socket;
exit
EOF
    
    if [[ $? -ne 0 ]]; then
      handle_failure "MariaDB 비밀번호 설정" "MariaDB 기본 비밀번호 설정 실패"
      return 1
    fi
    
    show_success "MariaDB 기본 비밀번호 설정 완료!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    show_info "Standby 서버이므로 MariaDB 비밀번호 설정을 건너뜁니다."
  fi
  
  # MariaDB 서비스 중지 (Galera 설정을 위해)
  show_progress "MariaDB 서비스 중지 중... (Galera 설정을 위해)"
  sudo systemctl stop mariadb
  if [[ $? -ne 0 ]]; then
    handle_failure "MariaDB 서비스 중지" "MariaDB 서비스 중지 실패"
    return 1
  fi
  show_success "MariaDB 서비스 중지 완료"
  
  show_success "MariaDB 설치 및 설정 완료!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================
# SECTION 6: GALERA CLUSTER FUNCTIONS
# =============================================

configure_galera() {
  if [[ "$subtype" != "이중화 서버" ]]; then
    show_info "단일 서버이므로 Galera 설정을 건너뜁니다."
    return 0
  fi
  
  clear_screen_and_logo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "                           🔄 Galera 클러스터 설정"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  show_progress "Galera 클러스터 설정을 시작합니다..."
  
  # Active/Standby 서버 구분
  if [[ "$status" == "Active" ]]; then
    show_info "Active 서버에서 Galera 설정을 진행합니다."
    NODE_NAME="server1"
    CLUSTER_ADDR="gcomm://$STANDBY_IP,$ip"
  else
    show_info "Standby 서버에서 Galera 설정을 진행합니다."
    NODE_NAME="server2"
    CLUSTER_ADDR="gcomm://$ACTIVE_IP,$ip"
    
    # Active 서버 설정 완료 확인
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                           ⏳ Active 서버 설정 완료 확인"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    show_info "Active 서버($ACTIVE_IP)에서 Galera 설정이 완료되었는지 확인하세요."
    read -p "Active 서버 설정이 완료되었습니까? (y/n): " active_ready
    if [[ "$active_ready" != "y" && "$active_ready" != "Y" ]]; then
      show_warning "Active 서버 설정 완료 후 다시 진행하세요."
      return 1
    fi
  fi
  
  # Galera 설정 파일 생성
  show_progress "Galera 설정 파일 생성 중..."
  
  # [galera] 섹션이 이미 있는지 확인하고 주석 해제 및 설정 업데이트
  if grep -q "^\[galera\]" /etc/my.cnf.d/server.cnf; then
    show_info "[galera] 섹션이 존재합니다. 기존 설정을 백업하고 업데이트합니다."
    sudo cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.galera.backup
    
    # 기존 [galera] 섹션의 주석 처리된 설정들을 활성화하고 업데이트
    sudo sed -i '/^\[galera\]/,/^\[/ { /^\[galera\]/! /^\[/! s/^#//; }' /etc/my.cnf.d/server.cnf
    
    # 필요한 설정들을 추가/업데이트
    sudo sed -i '/^\[galera\]/a wsrep_on=ON' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_provider=/usr/lib64/galera-4/libgalera_smm.so' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_cluster_name=galera' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_node_address='$ip /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_node_name='$NODE_NAME /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_sst_auth=mysql:' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_cluster_address="'$CLUSTER_ADDR'"' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a binlog_format=row' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a default_storage_engine=InnoDB' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a innodb_autoinc_lock_mode=2' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_sst_method=mariabackup' /etc/my.cnf.d/server.cnf
    sudo sed -i '/^\[galera\]/a wsrep_provider_options="pc.ignore_sb=true"' /etc/my.cnf.d/server.cnf
  else
    # [galera] 섹션이 없으면 새로 추가
    sudo tee -a /etc/my.cnf.d/server.cnf > /dev/null <<EOF

[galera]
wsrep_on=ON
wsrep_provider=/usr/lib64/galera-4/libgalera_smm.so
wsrep_cluster_name=galera
wsrep_node_address=$ip
wsrep_node_name=$NODE_NAME
wsrep_sst_auth=mysql:
wsrep_cluster_address="$CLUSTER_ADDR"
binlog_format=row
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
wsrep_sst_method=mariabackup
wsrep_provider_options="pc.ignore_sb=true"
EOF
  fi
  
  if [[ $? -ne 0 ]]; then
    handle_failure "Galera 설정 파일 생성" "Galera 설정 파일 생성 실패"
    return 1
  fi
  
  show_success "Galera 설정이 완료되었습니다."
  show_info "설정 파일: /etc/my.cnf.d/server.cnf"
  
  # Active 서버와 Standby 서버별 다른 처리
  if [[ "$status" == "Active" ]]; then
    # Active 서버: galera_new_cluster 시작
    show_progress "Active 서버에서 Galera 클러스터 시작 중..."
    sudo galera_new_cluster
    
    show_progress "MariaDB 프로세스 확인 중..."
    ps -ef | grep mysql
    
    # wsrep_start_position 확인
    show_progress "wsrep_start_position 확인 중..."
    local wsrep_position=$(ps -ef | grep mariadbd | grep -o "wsrep_start_position=[^[:space:]]*" | cut -d= -f2)
    
    if [[ "$wsrep_position" == "00000000-0000-0000-0000-000000000000:-1" ]]; then
      show_warning "wsrep_start_position이 0000으로 표시됩니다. grastate.dat 파일을 수정합니다."
      
      show_progress "MariaDB 서비스 중지 중..."
      sudo systemctl stop mariadb
      
      show_progress "grastate.dat 파일 수정 중..."
      sudo sed -i 's/Safe_to_bootstrap: 0/Safe_to_bootstrap: 1/' /var/lib/mysql/grastate.dat
      
      show_progress "Galera 클러스터 재시작 중..."
      sudo galera_new_cluster
      
      show_progress "MariaDB 프로세스 재확인 중..."
      ps -ef | grep mysql
    fi
    
    show_success "Active 서버 Galera 클러스터 시작 완료!"
    
    # Standby 서버 진행 대기
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                           ⏳ Standby 서버 진행 대기"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    show_info "Standby 서버($STANDBY_IP)에서 Galera 설정을 진행하세요."
    read -p "Standby 서버 설정을 진행하시겠습니까? (y/n): " standby_ready
    
  else
    # Standby 서버: 일반 MariaDB 시작
    show_progress "Standby 서버에서 MariaDB 시작 중..."
    sudo systemctl start mariadb
    
    show_progress "MariaDB 프로세스 확인 중..."
    ps -ef | grep mysql
    
    # wsrep_start_position 확인
    show_progress "wsrep_start_position 확인 중..."
    local wsrep_position=$(ps -ef | grep mariadbd | grep -o "wsrep_start_position=[^[:space:]]*" | cut -d= -f2)
    
    if [[ "$wsrep_position" == "00000000-0000-0000-0000-000000000000:-1" ]]; then
      show_warning "wsrep_start_position이 0000으로 표시됩니다. MariaDB를 재시작합니다."
      
      show_progress "MariaDB 서비스 재시작 중..."
      sudo systemctl stop mariadb
      sudo systemctl start mariadb
      
      show_progress "MariaDB 프로세스 재확인 중..."
      ps -ef | grep mysql
    fi
    
    show_success "Standby 서버 MariaDB 시작 완료!"
    
    # 데이터베이스 및 사용자 생성
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "                           🗄️  데이터베이스 및 사용자 생성"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    show_info "MariaDB에 접속하여 데이터베이스와 사용자를 생성합니다."
    read -p "MariaDB 접속을 위해 Enter를 누르세요... " -r
    
    mysql -u root -p <<EOF
create database sonar default character set utf8;
show databases;
create user 'sonar' identified by 'mariadb2!';
grant usage on *.* to 'sonar'@localhost identified by 'mariadb2!'; 
grant all privileges on sonar.* to 'sonar'@'localhost' identified by 'mariadb2!';
grant all privileges on sonar.* to 'sonar'@'%' identified by 'mariadb2!';
flush privileges;
exit
EOF
    
    if [[ $? -ne 0 ]]; then
      handle_failure "데이터베이스 생성" "데이터베이스 및 사용자 생성 실패"
      return 1
    fi
    
    show_success "데이터베이스 및 사용자 생성 완료!"
  fi
  
  # 이중화 설정 확인
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "                           🔍 이중화 설정 확인"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  show_info "Galera 클러스터 상태를 확인합니다."
  read -p "클러스터 상태 확인을 위해 Enter를 누르세요... " -r
  
  mysql -u root -p <<EOF
show status like 'wsrep_%';
exit
EOF
  
  show_success "Galera 클러스터 설정 완료!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================
# SECTION 7: SYSTEM SECURITY CONFIGURATION
# =============================================

configure_system_security() {
  clear_screen_and_logo
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "                           🔒 시스템 보안 설정"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  show_progress "시스템 보안 설정을 시작합니다..."
  
  # SELinux 비활성화
  show_progress "SELinux 비활성화 설정 중..."
  sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
  if [[ $? -ne 0 ]]; then
    handle_failure "SELinux 설정" "SELinux 설정 파일 수정 실패"
    return 1
  fi
  
  sudo setenforce 0
  if [[ $? -ne 0 ]]; then
    handle_failure "SELinux 비활성화" "SELinux 일시적 비활성화 실패"
    return 1
  fi
  
  show_success "SELinux 상태: $(getenforce)"
  
  # 방화벽 설정
  show_progress "방화벽 설정 중..."
  show_info "현재 방화벽 상태: $(sudo firewall-cmd --state)"
  
  show_progress "필요한 TCP 포트 개방 중..."
  for port in 443 3306 8443 7140 44300 18443 4444 4567 4568; do
    sudo firewall-cmd --permanent --add-port=${port}/tcp
    if [[ $? -ne 0 ]]; then
      handle_failure "방화벽 TCP 포트 설정" "포트 $port TCP 개방 실패"
      return 1
    fi
  done
  
  show_progress "필요한 UDP 포트 개방 중..."
  for port in 514 162; do
    sudo firewall-cmd --permanent --add-port=${port}/udp
    if [[ $? -ne 0 ]]; then
      handle_failure "방화벽 UDP 포트 설정" "포트 $port UDP 개방 실패"
      return 1
    fi
  done
  
  sudo firewall-cmd --reload
  if [[ $? -ne 0 ]]; then
    handle_failure "방화벽 설정 리로드" "방화벽 설정 리로드 실패"
    return 1
  fi
  
  show_success "방화벽 설정 완료"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================
# SECTION 8: MAIN EXECUTION
# =============================================

main() {
  clear
  draw_logo
  echo "────────────────────────────────────────────────────────────────"
  echo "                🚀 Logpresso Auto Builder"
  echo "                    자동 설치 프로그램"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
  show_info "시스템 준비를 시작합니다..."
  sleep 2

  install_pip_and_gdown

  clear_screen_and_logo
  ip=$(hostname -I | awk '{print $1}')
  show_info "현재 서버 IP: $ip"
  echo "────────────────────────────────────────────"
  sleep 2

  select_install_type
  select_subtype

  if [[ "$subtype" == "이중화 서버" ]]; then
    select_ha_status
  else
    status="Active"
  fi

  if [[ "$type" == "분석" ]]; then
    select_directory
    show_progress "필요한 디렉토리 생성 중..."
    sudo mkdir -p "$base_dir" /data/logpresso-data "$base_dir/log"

    select_mariadb_install_method

    if [[ "$mdb_choice" == "1" ]]; then
      # 다운로드 방식
      file_url='https://drive.google.com/uc?id=1MIQFGbar1gcQl19dkhrzSG3EyKY_a-XT'
      download_file="${base_dir}/Mariadb-10.11.13.tar"

      # 이미 다운로드된 파일이 있는지 확인
      if [[ -f "$download_file" ]]; then
        show_info "이미 다운로드된 파일이 발견되었습니다: $download_file"
        read -p "기존 파일을 사용하시겠습니까? (y/n): " use_existing
        if [[ "$use_existing" != "y" && "$use_existing" != "Y" ]]; then
          show_progress "기존 파일 삭제 중..."
          sudo rm -f "$download_file"
        fi
      fi

      # 이미 압축 해제된 디렉토리가 있는지 확인
      mariadb_extracted_dir=$(find "$base_dir" -maxdepth 1 -type d -name "*mariadb*" -o -name "*MariaDB*" | head -1)
      if [[ -n "$mariadb_extracted_dir" ]]; then
        show_info "이미 압축 해제된 MariaDB 디렉토리가 발견되었습니다: $mariadb_extracted_dir"
        read -p "기존 디렉토리를 사용하시겠습니까? (y/n): " use_existing_dir
        if [[ "$use_existing_dir" == "y" || "$use_existing_dir" == "Y" ]]; then
          show_success "기존 MariaDB 디렉토리를 사용합니다."
          # 다운로드 및 압축 해제 단계 건너뛰기
        else
          show_progress "기존 디렉토리 삭제 중..."
          sudo rm -rf "$mariadb_extracted_dir"
          # 다운로드 및 압축 해제 진행
        fi
      fi

      # 다운로드가 필요한 경우에만 진행
      if [[ ! -f "$download_file" || "$use_existing" != "y" && "$use_existing" != "Y" ]]; then
        clear_screen_and_logo
        show_progress "MariaDB 다운로드 중..."
        sudo python3 -m gdown "$file_url" -O "$download_file" --quiet

        if [[ $? -ne 0 || ! -f "$download_file" ]]; then
          show_warning "gdown 다운로드 실패, curl로 대체 다운로드 시도 중..."
          file_id="1MIQFGbar1gcQl19dkhrzSG3EyKY_a-XT"
          curl_download_gdrive "$file_id" "$download_file" || { 
            handle_failure "MariaDB 다운로드" "gdown 및 curl 다운로드 모두 실패"
            return 1
          }
        fi
      fi

      # 압축 해제가 필요한 경우에만 진행
      if [[ -z "$mariadb_extracted_dir" || "$use_existing_dir" != "y" && "$use_existing_dir" != "Y" ]]; then
        show_progress "압축 해제 중..."
        sudo tar -xf "$download_file" -C "$base_dir" || { 
          handle_failure "MariaDB 압축 해제" "압축 해제 실패"
          return 1
        }
        show_success "압축 해제 완료!"
        sleep 2
      fi

      # 시스템 보안 설정
      configure_system_security

    else
      # 수동 업로드 방식
      while true; do
        clear_screen_and_logo
        show_info "수동 업로드 확인 - 디렉토리: $base_dir"
        files=($(find "$base_dir" -maxdepth 1 -type f -printf "%f\n" 2>/dev/null))
        if [[ ${#files[@]} -eq 0 ]]; then
          show_warning "업로드된 파일이 없습니다."
          read -p "📁 파일 업로드 후 엔터를 눌러 다시 검사하세요."
          continue
        fi
        echo "📋 감지된 파일 목록:"
        for i in "${!files[@]}"; do
          echo "   $((i+1)). ${files[$i]}"
        done
        read -p "🎯 설치할 파일 번호를 선택하세요: " file_choice
        if [[ "$file_choice" =~ ^[0-9]+$ && $file_choice -ge 1 && $file_choice -le ${#files[@]} ]]; then
          selected_file="${base_dir}/${files[$((file_choice-1))]}"
          show_success "선택된 파일: $selected_file"
          show_progress "압축 해제 중..."
          sudo tar -xf "$selected_file" -C "$base_dir" || { 
            handle_failure "수동 업로드 압축 해제" "압축 해제 실패"
            return 1
          }
          show_success "압축 해제 완료!"
          sleep 2
          break
        else
          show_error "번호를 정확히 입력하세요."
          sleep 1
        fi
      done
    fi
    
    # MariaDB 설치 및 설정 실행 (분석 유형에서만)
    install_mariadb
    if [[ $? -ne 0 ]]; then
      handle_failure "MariaDB 설치" "MariaDB 설치 및 설정 실패"
    fi
    
    # Galera 클러스터 설정 (이중화 서버인 경우)
    if [[ "$subtype" == "이중화 서버" ]]; then
      configure_galera
      if [[ $? -ne 0 ]]; then
        handle_failure "Galera 설정" "Galera 클러스터 설정 실패"
      fi
    fi
  fi

  # =============================================
  # SECTION 9: FINAL SUMMARY
  # =============================================
  
  clear_screen_and_logo
  echo "────────────────────────────────────────────────────────────────"
  echo "                    📊 설치 완료 요약"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
  echo "🔧 설치 유형    : $type"
  echo "🖥️  세부 유형    : $subtype"
  echo "🔄 상태         : $status"
  
  if [[ "$subtype" == "이중화 서버" ]]; then
    echo "🟢 Active 서버  : ${ACTIVE_IP:-미입력}"
    echo "🟡 Standby 서버 : ${STANDBY_IP:-미입력}"
  fi
  
  echo "🌐 등록 IP      : $ip"
  
  if [[ "$type" == "분석" ]]; then
    echo "📁 설치 디렉토리 : $base_dir"
    if [[ "$mdb_choice" == "1" ]]; then
      echo "🗄️  MariaDB 설치 : ✅ 다운로드 및 압축 해제 완료"
    else
      echo "🗄️  MariaDB 설치 : ✅ 수동 업로드 처리 완료"
    fi
    echo "⚙️  MariaDB 설정 : ✅ 완료"
    if [[ "$status" == "Active" ]]; then
      echo "🔑 MariaDB 비밀번호 : mariadb1!"
    else
      echo "🔑 MariaDB 비밀번호 : Active 서버에서 설정됨"
    fi
    if [[ "$subtype" == "이중화 서버" ]]; then
      echo "🔄 Galera 설정  : ✅ 완료"
    fi
  fi
  
  echo ""
  echo "────────────────────────────────────────────────────────────────"
  echo "                    🎉 설치가 완료되었습니다!"
  echo "────────────────────────────────────────────────────────────────"
  echo ""
  show_info "다음 단계를 진행하시기 바랍니다."
}

# 스크립트 실행
main "$@"
