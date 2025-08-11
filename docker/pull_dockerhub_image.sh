#!/usr/bin/env bash
set -euo pipefail

DO_LOAD=0  # 是否在下载后执行 docker load

check_deps() {
  for cmd in curl jq uname tar docker; do
    if ! command -v $cmd >/dev/null 2>&1; then
      if [[ $cmd == docker && $DO_LOAD -eq 1 ]]; then
        echo "需要命令: docker (请先安装) 来加载镜像"
        exit 1
      elif [[ $cmd != docker ]]; then
        echo "需要命令: $cmd (请先安装)"
        exit 1
      fi
    fi
  done
}

update_self() {
  local self_path tmpfile
  self_path="$(readlink -f "$0")"
  tmpfile="$(mktemp)"
  if curl -fsSL "https://raw.githubusercontent.com/wbmins/shell/refs/heads/main/docker/pull_dockerhub_image.sh" -o "$tmpfile"; then
    if [[ -s "$tmpfile" ]]; then
      mv "$tmpfile" "$self_path"
      chmod +x "$self_path"
      echo "Update: Success"
      exit 0
    else
      echo "下载文件为空，更新失败。"
      rm -f "$tmpfile"
      exit 1
    fi
  else
    echo "下载失败，更新中止。"
    rm -f "$tmpfile"
    exit 1
  fi
}

parse_args() {
  if [[ $# -lt 1 ]]; then
    cat <<USAGE
用法: $0 [load] <image[:tag]> [arch]
示例:
  $0 nginx
  $0 wbmins/openwrt:alpha
  $0 nginx:1.25.1 amd64
  $0 load nginx:1.25.1 amd64
USAGE
    exit 1
  fi

  if [[ "$1" == "load" ]]; then
    DO_LOAD=1
    shift
  fi

  if [[ $# -lt 1 ]]; then
    echo "请提供镜像名参数"
    exit 1
  fi

  RAW="$1"
  ARCH="${2:-}"

  IMAGE=""
  TAG=""

  # 解析 IMAGE 和 TAG
  if [[ "$RAW" == *@* ]]; then
    IMAGE="${RAW%@*}"
    TAG="${RAW#*@}"
  else
    local last="${RAW##*/}"
    if [[ "$last" == *:* ]]; then
      TAG="${last#*:}"
      IMAGE="${RAW%:*}"
    else
      IMAGE="$RAW"
      TAG="latest"
    fi
  fi

  # 架构默认判断
  if [[ -z "$ARCH" ]]; then
    local machine_arch
    machine_arch=$(uname -m)
    case "$machine_arch" in
      x86_64) ARCH="amd64" ;;
      aarch64|arm64) ARCH="arm64" ;;
      *) echo "仅支持 amd64 和 arm64 架构，当前架构: $machine_arch ，请手动传入 arch 参数（amd64 或 arm64）"; exit 1 ;;
    esac
  fi

  # 判断是否是完整域名
  if [[ "$IMAGE" == *.*/* || "$IMAGE" == *:*/* ]]; then
    # 有域名的镜像
    REGISTRY_HOST="${IMAGE%%/*}"
    REPO_PATH="${IMAGE#*/}"
  else
    # 没有域名的，默认 docker.io
    REGISTRY_HOST="docker.io"
    REPO_PATH="$IMAGE"
  fi

  # docker hub repository 格式调整
  if [[ "$REGISTRY_HOST" == "docker.io" ]]; then
    if [[ "$REPO_PATH" != */* ]]; then
      Image="library/$REPO_PATH"
    else
      Image="$REPO_PATH"
    fi
    REPO="registry-1.docker.io"
  elif [[ "$REGISTRY_HOST" == "ghcr.io" ]]; then
    Image="$REGISTRY_HOST/$REPO_PATH"
    REPO="ghcr.io"
  else
    echo "仅支持 docker.io 和 ghcr.io 镜像"
    exit 1
  fi
}

echo_info() {
  printf "Repo:         %s\n" "$REPO"
  printf "Image:        %s\n" "$Image"
  printf "Tag:          %s\n" "$TAG"
  printf "Arch:         %s\n" "$ARCH"
}

get_token() {
  local token_json
  if [[ "$REPO" == "registry-1.docker.io" ]]; then
    token_json=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${Image}:pull")
  elif [[ "$REPO" == "ghcr.io" ]]; then
    token_json=$(curl -s "https://ghcr.io/token?scope=repository:${Image}:pull")
  else
    echo "未知 Registry，不支持获取 token"
    exit 1
  fi
  TOKEN=$(jq -r '.token // empty' <<<"$token_json")
  if [[ -z "$TOKEN" ]]; then
    echo "获取 token 失败："
    echo "$token_json"
    exit 1
  fi
}

get_manifest() {
  MANIFEST_FILE="$WORKDIR/manifest.json"
  local http_code

  http_code=$(curl -s -o "$MANIFEST_FILE" -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.v2+json,application/vnd.oci.image.manifest.v1+json" \
    "https://${REPO}/v2/${Image}/manifests/${TAG}")

  if [[ "$http_code" != "200" ]]; then
    echo "请求 manifest 失败 HTTP $http_code，返回内容："
    sed -n '1,200p' "$MANIFEST_FILE"
    exit 1
  fi

  if ! jq -e . "$MANIFEST_FILE" >/dev/null 2>&1; then
    echo "返回的 manifest 不是合法 JSON，内容如下："
    sed -n '1,200p' "$MANIFEST_FILE"
    exit 1
  fi

  KIND=$(jq -r 'if has("manifests") then "list" elif has("layers") then "manifest" else "unknown" end' "$MANIFEST_FILE")

  MANIFEST_SINGLE="$MANIFEST_FILE"

  if [[ "$KIND" == "list" ]]; then
    DIGEST=$(jq -r --arg arch "$ARCH" '.manifests[] | select(.platform.architecture==$arch) | .digest' "$MANIFEST_FILE" | head -n1)
    if [[ -z "$DIGEST" ]]; then
      echo "未找到架构 $ARCH 的 manifest。可用平台列表："
      jq -r '.manifests[] | "\(.digest) \(.platform.os)//\(.platform.architecture) \(.platform.variant // "")"' "$MANIFEST_FILE"
      exit 1
    fi
    MANIFEST_SINGLE="$WORKDIR/manifest_single.json"
    http_code=$(curl -s -o "$MANIFEST_SINGLE" -w '%{http_code}' \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.docker.distribution.manifest.v2+json,application/vnd.oci.image.manifest.v1+json" \
      "https://${REPO}/v2/${Image}/manifests/${DIGEST}")
    if [[ "$http_code" != "200" ]]; then
      echo "请求单架构 manifest 失败 HTTP $http_code，内容："
      sed -n '1,200p' "$MANIFEST_SINGLE"
      exit 1
    fi
  fi
}

get_layers() {
  LAYERS=()
  while IFS= read -r d; do
    [[ -n "$d" ]] && LAYERS+=("$d")
  done < <(jq -r '.layers[]?.digest // empty' "$MANIFEST_SINGLE")

  if [[ ${#LAYERS[@]} -eq 0 ]]; then
    echo "manifest 中没有 layers 字段，输出 manifest 内容以便排查："
    jq . "$MANIFEST_SINGLE"
    exit 1
  fi

  for i in "${!LAYERS[@]}"; do
    local digest="${LAYERS[$i]}"
    local base="${digest#sha256:}"
    local out="$WORKDIR/${base}.tar.gz"
    printf "Layer %d/%d:    " "$((i+1))" "${#LAYERS[@]}"
    if curl -sL -H "Authorization: Bearer $TOKEN" "https://${REPO}/v2/${Image}/blobs/${digest}" -o "$out"; then
      echo "✔"
    else
      echo "下载失败"
      exit 1
    fi
  done

  CONFIG_DIGEST=$(jq -r '.config.digest // empty' "$MANIFEST_SINGLE")
  if [[ -z "$CONFIG_DIGEST" ]]; then
    echo "无法从 manifest 读取 config.digest"
    exit 1
  fi
  config_base="${CONFIG_DIGEST#sha256:}"
  config_file="$WORKDIR/${config_base}.json"
  curl -sL -H "Authorization: Bearer $TOKEN" "https://${REPO}/v2/${Image}/blobs/${CONFIG_DIGEST}" -o "$config_file"
}

pack_image() {
  USER_REPO_TAG="${RAW%:*}"
  if [[ "$USER_REPO_TAG" == "$RAW" ]]; then
    if [[ "${IMAGE}" == library/* ]]; then
      REPO_FOR_TAG="${IMAGE#library/}"
    else
      REPO_FOR_TAG="$IMAGE"
    fi
    REPO_TAG="${REPO_FOR_TAG}:${TAG}"
  else
    REPO_TAG="${USER_REPO_TAG}:${TAG}"
  fi

  LAYER_BASENAMES=()
  for digest in "${LAYERS[@]}"; do
    LAYER_BASENAMES+=("${digest#sha256:}.tar.gz")
  done

  MANIFEST_FOR_SAVE="$WORKDIR/manifest.json"
  layers_json=""
  for i in "${!LAYER_BASENAMES[@]}"; do
    [[ $i -gt 0 ]] && layers_json+=","
    layers_json+="\"${LAYER_BASENAMES[$i]}\""
  done

  cat > "$MANIFEST_FOR_SAVE" <<EOF
[{
  "Config": "${config_base}.json",
  "RepoTags": ["${REPO_TAG}"],
  "Layers": [${layers_json}]
}]
EOF

  OUTFILE="${Image//\//_}-${TAG}.tar"
  tar -C "$WORKDIR" -cf "$OUTFILE" manifest.json "${config_base}.json" "${LAYER_BASENAMES[@]}"

  if [[ "$DO_LOAD" -eq 1 ]]; then
    echo "开始加载镜像到 docker..."
    docker load -i "$OUTFILE"
    echo "加载完成。"
    rm -f "$OUTFILE"
  else
    printf "Done:         docker load -i %s\n" "$OUTFILE"
  fi
}

######################################## main ########################################
check_deps

if [[ "${1:-}" == "update" ]]; then
  update_self
fi

parse_args "$@"

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo_info
get_token
get_manifest
get_layers
pack_image
######################################## main ########################################
