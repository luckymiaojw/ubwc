#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./vrf/sim/open_wave.sh <group> <case> [mode] [--dry-run]

Groups:
  dec    : decoder wrapper
  enc    : encoder wrapper
  encdec : encoder+decoder wrapper

Cases:
  rgba8888
  rgba1010102
  nv12
  g016
  nv12_otf   (dec only)

Modes:
  dec    : fake | real        (default: fake)
  enc    : fake | nonfake     (default: fake)
  encdec : ignored

Examples:
  ./vrf/sim/open_wave.sh dec rgba8888
  ./vrf/sim/open_wave.sh dec nv12 real
  ./vrf/sim/open_wave.sh dec nv12_otf fake
  ./vrf/sim/open_wave.sh enc nv12
  ./vrf/sim/open_wave.sh enc g016 nonfake
  ./vrf/sim/open_wave.sh encdec nv12
  ./vrf/sim/open_wave.sh dec nv12 fake --dry-run
EOF
}

find_csh_shell() {
    if command -v tcsh >/dev/null 2>&1; then
        printf '%s\n' "tcsh"
        return 0
    fi
    if command -v csh >/dev/null 2>&1; then
        printf '%s\n' "csh"
        return 0
    fi
    return 1
}

canon_case_name() {
    case "$1" in
        rgba8888|rgba)
            printf '%s\n' "rgba8888"
            ;;
        rgba1010102|1010102|rgba10)
            printf '%s\n' "rgba1010102"
            ;;
        nv12)
            printf '%s\n' "nv12"
            ;;
        g016|p010)
            printf '%s\n' "g016"
            ;;
        nv12_otf|otf)
            printf '%s\n' "nv12_otf"
            ;;
        *)
            return 1
            ;;
    esac
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SIM_DIR="${PROJECT_ROOT}/vrf/sim"
ENV_SCRIPT="${PROJECT_ROOT}/prj_setup.env"

if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
    usage
    exit 0
fi

DRY_RUN=0
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            ;;
    esac
    shift
done

if [[ ${#POSITIONAL[@]} -lt 2 || ${#POSITIONAL[@]} -gt 3 ]]; then
    usage >&2
    exit 1
fi

GROUP="${POSITIONAL[0]}"
RAW_CASE="${POSITIONAL[1]}"
MODE="${POSITIONAL[2]:-}"

CASE_NAME="$(canon_case_name "${RAW_CASE}")" || {
    echo "Unsupported case: ${RAW_CASE}" >&2
    usage >&2
    exit 1
}

if [[ ! -f "${ENV_SCRIPT}" ]]; then
    echo "Cannot find env script: ${ENV_SCRIPT}" >&2
    exit 1
fi

CSH_BIN="$(find_csh_shell)" || {
    echo "Cannot find tcsh/csh in PATH." >&2
    exit 1
}

MAKE_ARGS=()

case "${GROUP}" in
    dec)
        if [[ -z "${MODE}" ]]; then
            MODE="fake"
        fi
        if [[ "${MODE}" != "fake" && "${MODE}" != "real" ]]; then
            echo "dec mode must be fake or real" >&2
            exit 1
        fi
        case "${CASE_NAME}" in
            rgba8888)
                MAKE_ARGS=("WRAPPER_NV12_VIVO_MODE=${MODE}" "wrapper_tajmahal_4096x600_rgba8888_vivo_verdi")
                ;;
            rgba1010102)
                MAKE_ARGS=("WRAPPER_NV12_VIVO_MODE=${MODE}" "wrapper_tajmahal_4096x600_rgba1010102_vivo_verdi")
                ;;
            nv12)
                MAKE_ARGS=("WRAPPER_NV12_VIVO_MODE=${MODE}" "wrapper_tajmahal_4096x600_nv12_vivo_verdi")
                ;;
            g016)
                MAKE_ARGS=("WRAPPER_NV12_VIVO_MODE=${MODE}" "wrapper_k_outdoor61_4096x600_g016_vivo_verdi")
                ;;
            nv12_otf)
                MAKE_ARGS=("wrapper_tajmahal_4096x600_nv12_otf_${MODE}_verdi")
                ;;
        esac
        ;;
    enc)
        if [[ -z "${MODE}" ]]; then
            MODE="fake"
        fi
        if [[ "${MODE}" != "fake" && "${MODE}" != "nonfake" ]]; then
            echo "enc mode must be fake or nonfake" >&2
            exit 1
        fi
        case "${CASE_NAME}" in
            rgba8888)
                if [[ "${MODE}" == "fake" ]]; then
                    MAKE_ARGS=("TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888" "verdi")
                else
                    MAKE_ARGS=("enc_wrapper_tajmahal_4096x600_rgba8888_verdi")
                fi
                ;;
            rgba1010102)
                if [[ "${MODE}" == "fake" ]]; then
                    MAKE_ARGS=("TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102" "verdi")
                else
                    MAKE_ARGS=("enc_wrapper_tajmahal_4096x600_rgba1010102_verdi")
                fi
                ;;
            nv12)
                if [[ "${MODE}" == "fake" ]]; then
                    MAKE_ARGS=("TOP=tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12" "verdi")
                else
                    MAKE_ARGS=("enc_wrapper_tajmahal_4096x600_nv12_verdi")
                fi
                ;;
            g016)
                if [[ "${MODE}" == "fake" ]]; then
                    MAKE_ARGS=("TOP=tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016" "verdi")
                else
                    MAKE_ARGS=("enc_wrapper_k_outdoor61_4096x600_g016_verdi")
                fi
                ;;
            nv12_otf)
                echo "nv12_otf is only supported for dec." >&2
                exit 1
                ;;
        esac
        ;;
    encdec)
        if [[ "${CASE_NAME}" != "nv12" ]]; then
            echo "encdec currently only supports nv12." >&2
            exit 1
        fi
        MAKE_ARGS=("encdec_wrapper_tajmahal_4096x600_nv12_verdi")
        ;;
    *)
        echo "Unsupported group: ${GROUP}" >&2
        usage >&2
        exit 1
        ;;
esac

cmd="source \"${ENV_SCRIPT}\"; make -C \"${SIM_DIR}\""
for arg in "${MAKE_ARGS[@]}"; do
    cmd="${cmd} \"${arg}\""
done

echo "Project root : ${PROJECT_ROOT}"
echo "SIM dir      : ${SIM_DIR}"
echo "Wave request : group=${GROUP} case=${CASE_NAME} mode=${MODE:-default}"
echo "Command      : make -C ${SIM_DIR} ${MAKE_ARGS[*]}"

if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "[DRY-RUN] ${CSH_BIN} -c '${cmd}'"
    exit 0
fi

"${CSH_BIN}" -c "${cmd}"
