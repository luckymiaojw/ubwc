#!/usr/bin/env bash
set -uo pipefail

usage() {
    cat <<'EOF'
Usage:
  ./vrf/sim/run_random_if_cases.sh [all|dec|enc] [--seeds "101 202"] [--dry-run]

Description:
  Run wrapper fake-mode random interface stress cases.  The random knobs are
  all plusargs, so every failed seed is reproducible from the printed command.

Random knobs used:
  ENC: +tb_otf_random +tb_otf_hblank_gap_max=<N>
       +tb_axi_random +tb_axi_aw_stall_pct=<P> +tb_axi_w_stall_pct=<P>
  DEC: +tb_otf_ready_random +tb_otf_ready_stall_pct=<P>
       +tb_axi_random +tb_axi_ar_stall_pct=<P> +tb_axi_rvalid_stall_pct=<P>

Examples:
  ./vrf/sim/run_random_if_cases.sh
  ./vrf/sim/run_random_if_cases.sh dec --seeds "11 29 47"
  ./vrf/sim/run_random_if_cases.sh enc --dry-run
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
SEEDS=(101 202)

while [[ $# -gt 0 ]]; do
    case "$1" in
        all|dec|enc)
            TARGET_GROUPS+=("$1")
            ;;
        --seeds)
            shift
            if [[ $# -eq 0 ]]; then
                echo "--seeds requires a quoted seed list" >&2
                exit 1
            fi
            read -r -a SEEDS <<< "$1"
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
RUN_ARGS_LIST=()

append_case() {
    local target="$1"
    local args="$2"
    TARGETS+=("${target}")
    RUN_ARGS_LIST+=("${args}")
}

append_dec_targets() {
    local seed="$1"
    local otf_seed=$((seed + 17))
    local axi_seed=$((seed + 131))

    append_case \
        "wrapper_tajmahal_4096x600_nv12_otf_fake_all" \
        "+tb_frame_repeat=2 +tb_timeout_cycles=24000000 +tb_idle_gap_cycles=8000000 +tb_otf_ready_random +tb_otf_ready_seed=${otf_seed} +tb_otf_ready_stall_pct=20 +tb_axi_random +tb_axi_seed=${axi_seed} +tb_axi_ar_stall_pct=25 +tb_axi_rvalid_stall_pct=35"

    append_case \
        "wrapper_k_outdoor61_4096x600_g016_vivo_fake_all" \
        "+tb_frame_repeat=2 +tb_timeout_cycles=24000000 +tb_idle_gap_cycles=8000000 +tb_otf_ready_random +tb_otf_ready_seed=$((otf_seed + 1)) +tb_otf_ready_stall_pct=18 +tb_axi_random +tb_axi_seed=$((axi_seed + 1)) +tb_axi_ar_stall_pct=20 +tb_axi_rvalid_stall_pct=30"
}

append_enc_targets() {
    local seed="$1"
    local otf_seed=$((seed + 23))
    local axi_seed=$((seed + 197))

    append_case \
        "enc_wrapper_tajmahal_4096x600_nv12_fake_all" \
        "+tb_frame_repeat=2 +tb_timeout_cycles=24000000 +tb_otf_random +tb_otf_gap_seed=${otf_seed} +tb_otf_hblank_gap_max=3 +tb_axi_random +tb_axi_seed=${axi_seed} +tb_axi_aw_stall_pct=20 +tb_axi_w_stall_pct=30"

    append_case \
        "enc_wrapper_k_outdoor61_4096x600_g016_fake_all" \
        "+tb_frame_repeat=2 +tb_timeout_cycles=24000000 +tb_otf_random +tb_otf_gap_seed=$((otf_seed + 1)) +tb_otf_hblank_gap_max=4 +tb_axi_random +tb_axi_seed=$((axi_seed + 1)) +tb_axi_aw_stall_pct=18 +tb_axi_w_stall_pct=28"
}

for seed in "${SEEDS[@]}"; do
    for group in "${TARGET_GROUPS[@]}"; do
        case "${group}" in
            all)
                append_dec_targets "${seed}"
                append_enc_targets "${seed}"
                ;;
            dec)
                append_dec_targets "${seed}"
                ;;
            enc)
                append_enc_targets "${seed}"
                ;;
        esac
    done
done

run_make() {
    local target="$1"
    local run_args="$2"
    local cmd

    cmd="source \"${ENV_SCRIPT}\"; make -C \"${SIM_DIR}\" \"${target}\" RUN_ARGS=\"${run_args}\""
    if [[ ${DRY_RUN} -eq 1 ]]; then
        echo "[DRY-RUN] ${CSH_BIN} -c '${cmd}'"
        return 0
    fi

    "${CSH_BIN}" -c "${cmd}"
}

case_run_log() {
    local target="$1"

    case "${target}" in
        wrapper_tajmahal_4096x600_nv12_otf_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_dec_wrapper_top_tajmahal_4096x600_nv12_fake/run.log"
            ;;
        wrapper_k_outdoor61_4096x600_g016_vivo_fake_all)
            printf '%s\n' "${SIM_DIR}/build/tb_ubwc_dec_wrapper_top_k_outdoor61_4096x600_g016_fake/run.log"
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
fail_items=()
total_count="${#TARGETS[@]}"

echo "Project root : ${PROJECT_ROOT}"
echo "SIM dir      : ${SIM_DIR}"
echo "Shell        : ${CSH_BIN}"
echo "Seeds        : ${SEEDS[*]}"
echo "Targets      : ${total_count}"
echo

for idx in "${!TARGETS[@]}"; do
    target="${TARGETS[$idx]}"
    run_args="${RUN_ARGS_LIST[$idx]}"
    run_log="$(case_run_log "${target}")"
    build_dir="$(case_build_dir "${target}")"
    echo "==> [$((idx + 1))/${total_count}] ${target}"
    echo "RUN_ARGS=${run_args}"
    if [[ ${DRY_RUN} -eq 0 && -n "${build_dir}" && -d "${build_dir}" ]]; then
        rm -f "${build_dir}/simv"
    fi
    if run_make "${target}" "${run_args}" && ! case_log_has_failure "${run_log}"; then
        pass_count=$((pass_count + 1))
        echo "[PASS] ${target}"
    else
        fail_count=$((fail_count + 1))
        fail_items+=("${target} :: ${run_args}")
        echo "[FAIL] ${target}"
        if [[ -n "${run_log}" ]]; then
            echo "      log: ${run_log}"
        fi
    fi
    echo
done

echo "Summary: pass=${pass_count} fail=${fail_count}"
if [[ ${fail_count} -ne 0 ]]; then
    echo "Failed cases:"
    for item in "${fail_items[@]}"; do
        echo "  - ${item}"
    done
    exit 1
fi
