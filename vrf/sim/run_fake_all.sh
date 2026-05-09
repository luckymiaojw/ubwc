#!/usr/bin/env bash
set -uo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./vrf/sim/run_fake_all.sh [all|dec|enc] [--dry-run]

Description:
  Batch-run the commonly used fake-mode VCS regressions.

Groups:
  all : decoder fake + encoder fake
  dec : decoder fake only
  enc : encoder fake only

Examples:
  ./vrf/sim/run_fake_all.sh
  ./vrf/sim/run_fake_all.sh dec
  ./vrf/sim/run_fake_all.sh enc --dry-run
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SIM_DIR="${PROJECT_ROOT}/vrf/sim"
ENV_SCRIPT="${PROJECT_ROOT}/prj_setup.env"

if [[ ! -f "${ENV_SCRIPT}" ]]; then
    echo "Cannot find env script: ${ENV_SCRIPT}" >&2
    exit 1
fi

CSH_BIN="$(find_csh_shell)" || {
    echo "Cannot find tcsh/csh in PATH." >&2
    exit 1
}

DRY_RUN=0
TARGET_GROUPS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        all|dec|enc)
            TARGET_GROUPS+=("$1")
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

if [[ ${#TARGET_GROUPS[@]} -eq 0 ]]; then
    TARGET_GROUPS=("all")
fi

TARGETS=()

append_dec_targets() {
    TARGETS+=(
        "wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all"
        "wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all"
        "wrapper_tajmahal_4096x600_nv12_vivo_fake_all"
        "wrapper_k_outdoor61_4096x600_g016_vivo_fake_all"
        "wrapper_tajmahal_4096x600_nv12_otf_fake_all"
    )
}

append_enc_targets() {
    TARGETS+=(
        "enc_wrapper_tajmahal_4096x600_rgba8888_fake_all"
        "enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all"
        "enc_wrapper_tajmahal_4096x600_nv12_fake_all"
        "enc_wrapper_k_outdoor61_4096x600_g016_fake_all"
    )
}

for group in "${TARGET_GROUPS[@]}"; do
    case "${group}" in
        all)
            append_dec_targets
            append_enc_targets
            ;;
        dec)
            append_dec_targets
            ;;
        enc)
            append_enc_targets
            ;;
    esac
done

run_make() {
    local target="$1"
    local cmd

    cmd="source \"${ENV_SCRIPT}\"; make -C \"${SIM_DIR}\" \"${target}\""
    if [[ ${DRY_RUN} -eq 1 ]]; then
        echo "[DRY-RUN] ${CSH_BIN} -c '${cmd}'"
        return 0
    fi

    "${CSH_BIN}" -c "${cmd}"
}

case_run_log() {
    local target="$1"

    case "${target}" in
        wrapper_tajmahal_4096x600_rgba8888_vivo_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_dec_wrapper_top_tajmahal_4096x608_rgba8888_fake/run.log"
            ;;
        wrapper_tajmahal_4096x600_rgba1010102_vivo_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_dec_wrapper_top_tajmahal_4096x608_rgba1010102_fake/run.log"
            ;;
        wrapper_tajmahal_4096x600_nv12_vivo_fake_all|wrapper_tajmahal_4096x600_nv12_otf_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_fake/run.log"
            ;;
        wrapper_k_outdoor61_4096x600_g016_vivo_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_fake/run.log"
            ;;
        enc_wrapper_tajmahal_4096x600_rgba8888_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba8888_fake/run.log"
            ;;
        enc_wrapper_tajmahal_4096x600_rgba1010102_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_enc_wrapper_top_tajmahal_4096x600_rgba1010102_fake/run.log"
            ;;
        enc_wrapper_tajmahal_4096x600_nv12_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_enc_wrapper_top_tajmahal_4096x600_nv12_fake/run.log"
            ;;
        enc_wrapper_k_outdoor61_4096x600_g016_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_enc_wrapper_top_k_outdoor61_4096x600_g016_fake/run.log"
            ;;
        *)
            printf '%s\n' ""
            ;;
    esac
}

case_build_dir() {
    local run_log

    run_log="$(case_run_log "$1")"
    if [[ -n "${run_log}" ]]; then
        dirname "${run_log}"
    else
        printf '%s\n' ""
    fi
}

case_log_has_failure() {
    local log_file="$1"

    if [[ -z "${log_file}" || ! -f "${log_file}" ]]; then
        return 1
    fi

    grep -Eq '(^|[[:space:]])FAIL:|\[TB\]\[ERROR\]|\$fatal|Fatal:' "${log_file}"
}

fail_count=0
pass_count=0
fail_targets=()
total_count="${#TARGETS[@]}"

echo "Project root : ${PROJECT_ROOT}"
echo "SIM dir      : ${SIM_DIR}"
echo "Shell        : ${CSH_BIN}"
echo "Targets      : ${total_count}"
echo

for idx in "${!TARGETS[@]}"; do
    target="${TARGETS[$idx]}"
    run_log="$(case_run_log "${target}")"
    build_dir="$(case_build_dir "${target}")"
    echo "==> [$((idx + 1))/${total_count}] ${target}"
    if [[ ${DRY_RUN} -eq 0 && -n "${build_dir}" && -d "${build_dir}" ]]; then
        rm -f "${build_dir}/simv"
        rm -f "${build_dir}/simv.daidir/.vcs.timestamp"
    fi
    if run_make "${target}" && ! case_log_has_failure "${run_log}"; then
        pass_count=$((pass_count + 1))
        echo "[PASS] ${target}"
    else
        fail_count=$((fail_count + 1))
        fail_targets+=("${target}")
        echo "[FAIL] ${target}"
        if [[ -n "${run_log}" ]]; then
            echo "      log: ${run_log}"
        fi
    fi
    echo
done

echo "Summary: pass=${pass_count} fail=${fail_count}"
if [[ ${fail_count} -ne 0 ]]; then
    echo "Failed targets:"
    for target in "${fail_targets[@]}"; do
        echo "  - ${target}"
    done
    exit 1
fi
