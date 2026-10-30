#!/bin/sh
:<<'EOF'
Copyright © 2018 Torge Matthies <openglfreak@googlemail.com>
This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See http://www.wtfpl.net/ for more details.
EOF

# Lists the UUIDs of installed Nvidia GPUs (including the leading "GPU-")
#
# stdout:
#	UUIDs of installed Nvidia GPUs.
#
# stderr:
#	Errors from nvidia-smi.
#
# exit code:
#	The exit code of nvidia-smi.
list_gpu_ids() {
	nvidia-smi --query-gpu=gpu_uuid --format=csv,noheader,nounits
}

# Gets the default power limit of an Nvidia GPU
#
# params:
#	string id
#		The id of the GPU.
#
# stdout:
#	The default power limit of the GPU in watts.
#
# stderr:
#	Errors from nvidia-smi.
#
# exit code:
#	1 if not enough parameters were passed,
#	2 if too many parameters were passed,
#	the exit code of nvidia-smi otherwise.
get_default_power_limit() {
	if [ $# -ne 1 ]; then
		if [ $# -lt 1 ]; then
			# Not enough parameters
			return 1
		else
			# Too many parameters
			return 2
		fi
	fi
	
	nvidia-smi \
		--id="$1" \
		--query-gpu=power.default_limit \
		--format=csv,noheader,nounits
}
# Gets the minimum power limit of an Nvidia GPU
#
# params:
#	string id
#		The id of the GPU.
#
# stdout:
#	The minimum power limit of the GPU in watts.
#
# stderr:
#	Errors from nvidia-smi.
#
# exit code:
#	1 if not enough parameters were passed,
#	2 if too many parameters were passed,
#	the exit code of nvidia-smi otherwise.
get_min_power_limit() {
	if [ $# -ne 1 ]; then
		if [ $# -lt 1 ]; then
			# Not enough parameters
			return 1
		else
			# Too many parameters
			return 2
		fi
	fi
	
	nvidia-smi --id="$1" \
		--query-gpu=power.min_limit \
		--format=csv,noheader,nounits
}
# Gets the maximum power limit of an Nvidia GPU
#
# params:
#	string id
#		The id of the GPU.
#
# stdout:
#	The maximum power limit of the GPU in watts.
#
# stderr:
#	Errors from nvidia-smi.
#
# exit code:
#	1 if not enough parameters were passed,
#	2 if too many parameters were passed,
#	the exit code of nvidia-smi otherwise.
get_max_power_limit() {
	if [ $# -ne 1 ]; then
		if [ $# -lt 1 ]; then
			# Not enough parameters
			return 1
		else
			# Too many parameters
			return 2
		fi
	fi
	
	nvidia-smi --id="$1" \
		--query-gpu=power.max_limit \
		--format=csv,noheader,nounits
}

# Clamps numbers to a minimum and optionally a maximum.
#
# params:
#	number minimum
#		The minimum to clamp to, in a format accepted by awk.
#	[number maximum]
#		The maximum to clamp to, in a format accepted by awk.
#
# stdin:
#	The input numbers, one per line, in a format accepted by awk.
#
# stdout:
#	The clamped numbers.
clamp() {
	if [ $# -lt 1 ]; then
		# Not enough parameters
		return 1
	elif [ $# -gt 2 ]; then
		# Too many parameters
		return 2
	fi
	
	if [ $# -ge 2 ]; then
		set -- -v "minimum=$1" -v "maximum=$2"
	else
		set -- -v "minimum=$1"
	fi
	
	awk ${1+"$@"} '{
			v = +$0;
			if (v != $0)
				next;
			if (v < minimum)
				v = minimum;
			else if (maximum != "" && v > maximum)
				v = maximum;
			printf("%f", v);
		}' |\
		sed -n \
			-e '/\..*0$/{s/0\+$//g}' \
			-e 's/\.$//g' \
			-e '/^[0-9]\+\(\.[0-9]*\)\?$/{p;q}'
}

# Calculates the new power limit from an expression
#
# params:
#	string id
#		The id of the GPU.
#	string expr
#		Either a percentage of the default power limit, or a
#		bc expression to calculate the new power limit with.
#		The variables 'default', 'minimum' and 'maximum' contain the
#		default, minimum and maximum power limits respectively.
#		Examples:
#			90% = 90% of the default power limit
#			maximum - 10 = The maximum power limit minus 10 watts
#			minimum * 1.1 = 10% above the minimum power limit
#
# stdout:
#	The new computed power limit, clamped to the minimum and maximum
#	power limits, in watts.
#
# stderr:
#	Errors from get_default_power_limit, get_min_power_limit,
#	get_max_power_limit, clamp or bc.
#
# exit code:
#	1 if not enough parameters were passed,
#	2 if too many parameters were passed,
#	undefined otherwise.
power_limit_calc() {
	if [ $# -ne 2 ]; then
		if [ $# -lt 2 ]; then
			# Not enough parameters
			return 1
		else
			# Too many parameters
			return 2
		fi
	fi
	
	case "$2" in
		default)
			get_default_power_limit "$1"
			;;
		minimum)
			get_min_power_limit "$1"
			;;
		maximum)
			get_max_power_limit "$1"
			;;
		*)
		(
			default_power_limit="$(get_default_power_limit "$1")"
			min_power_limit="$(get_min_power_limit "$1")"
			max_power_limit="$(get_max_power_limit "$1")"
			case "$2" in
				*%)
					if printf '%s' "$2" |\
					   grep -q '^\([0-9]\+\|[0-9]*\.[0-9]*\)%$'
					then
						printf '%s*%s/100\n' \
							"$default_power_limit" \
							"${2%\%}" |\
							bc -lq |\
							clamp "$min_power_limit" "$max_power_limit"
					fi
					;;
				*)
					printf 'default=%s;minimum=%s;maximum=%s\n%s\n' \
						"$default_power_limit" \
						"$min_power_limit" \
						"$max_power_limit" \
						"$2" |\
						bc -lq |\
						clamp "$min_power_limit" "$max_power_limit"
					;;
			esac
		);;
	esac
}

# Checks wether the script is run as root or not.
#
# exit code:
#	1 if we don't have root,
#	0 otherwise.
check_root() {
	# shellcheck disable=SC2039
	if [ -n "${EUID:-}" ]; then
		test 0 -eq "$EUID"
	else
		test 0 -eq "$(($(id -u 2>/dev/null)+0))"
	fi
}

# Exits the shell with an error message if run as non-root
#
# params:
#	[int exit_code]
#		The exit code to exit with if we don't have root.
#	[string error_message]
#		The error message to write to stderr if we don't have root.
#
# stderr:
#	Error message if we don't have root.
#
# exit code:
#	No return on error,
#	0 otherwise.
require_root() {
	# shellcheck disable=SC2039
	if ! check_root; then
		printf '%s\n' "${2:-This script must be run as root.}" 1>&2
		exit $((${1:-1}))
	fi
}

# Process a section in a config file
#
# params:
#	string section_name
#		The name of the section
#	string file
#		The path of the file being read.
#
# stdin:
#	The open config file.
#
# variables:
#	in/out int linenum
#		The line number in the file
#	out string line
#		The first line after the section.
#
# exit code:
#	1 if not enough parameters were passed,
#	2 if too many parameters were passed,
#	0 otherwise.
process_section() {
	if [ $# -ne 2 ]; then
		if [ $# -lt 2 ]; then
			# Not enough parameters
			return 1
		else
			# Too many parameters
			return 2
		fi
	fi
	
	linenum=$((linenum))
	while IFS= read -r line; do
		linenum=$((linenum+1))
		
		case "$line" in
			# Section header
			\[*\])
				break
				;;
			# Option 'power_limit'
			power_limit=*)
				if ! check_root; then
					printf '%s\n' "$filename:$linenum: Warning: Setting the power limit requires root."
				fi
				
				(
					power_limit="$(power_limit_calc "$1" "${line#power_limit=}")" #"
					if [ -n "$power_limit" ]; then
						nvidia-smi --id="$1" --power-limit="$power_limit"
					else
						printf '%s\n' "$filename:$linenum: Warning: Could not compute new power limit: $line" 1>&2
					fi
				)
				;;
			# Option 'preferred_mode'
			preferred_mode=*)
				line="${line#preferred_mode=}"
				case "$line" in
					adaptive|Adaptive)
						line=0
						;;
					prefer_maximum_performance|'Prefer Maximum Performance')
						line=1
						;;
					auto|Auto)
						line=2
						;;
					*)
						if [ $((line)) -ne "$line" ]; then
							printf '%s\n' "$filename:$linenum: Error: Invalid value for option preferred_mode: $line" 1>&2
							continue
						fi
						line=$((line))
						if [ $line -lt 0 ] || [ $line -gt 2 ]; then
							printf '%s\n' "$filename:$linenum: Error: Invalid value for option preferred_mode: $line" 1>&2
							continue
						fi
						;;
				esac
				nvidia-settings --assign="[gpu:$1]/GPUPowerMizerMode=$line"
				;;
			# Option 'core_offset_mhz'
			core_offset_mhz=*)
				nvidia-settings --assign="[gpu:$1]/GPUGraphicsClockOffsetAllPerformanceLevels=${line#core_offset_mhz=}"
				;;
			# Option 'memory_offset_mhz'
			memory_offset_mhz=*)
				nvidia-settings --assign="[gpu:$1]/GPUMemoryTransferRateOffsetAllPerformanceLevels=${line#memory_offset_mhz=}"
				;;
			# Comment
			\#*) :;;
			# Empty line
			'') :;;
			# Other non-empty line
			*[![:space:]]*)
				# Comment with leading spaces
				case "${line%%#*}" in
					*[![:space:]]*) :;;
					*) continue;;
				esac
				# Invalid line
				printf '%s\n' "$filename:$linenum: Warning: Invalid line: $line" 1>&2
				;;
		esac
	done
}

# Process a config file
#
# params:
#	[string file]
#		The config file to be read. Defaults to stdin.
#
# exit code:
#	2 if too many parameters were passed,
#	0 otherwise.
process_file() {
	if [ $# -gt 1 ]; then
		# Too many parameters
		return 2
	fi
	
	(
		if [ $# -ge 1 ] && [ "$1" \!= - ]; then
			exec < "$1"
			filename="$1"
		else
			filename='stdin'
		fi
		
		linenum=0
		while IFS= read -r line; do
			linenum=$((linenum+1))
			
			case "$line" in
				# Section header
				\[*\])
					line="${line#[}"
					line="${line%]}"
					process_section "$line" "$filename"
					;;
				# Comment
				\#*) :;;
				# Empty line
				'') :;;
				# Other non-empty line
				*[![:space:]]*)
					# Comment with leading spaces
					case "${line%%#*}" in
						*[![:space:]]*) :;;
						*) continue;;
					esac
					# Invalid line
					printf '%s\n' "$filename:$linenum: Warning: Invalid line: $line" 1>&2
					;;
			esac
		done
	)
}

_print_help() {
	cat <<EOF
Usage: $0 -h|--help
       $0 --reset
       $0 [options]
Applies overclocking to Nvidia GPUs.
By default options are read from /etc/nvidia-oc.conf.

Options:
  -f, --file=FILE        Read a script from file FILE
EOF
}

# TODO: document
reset_gpu_params() {
	nvidia-smi --id="$1" --power-limit="$(get_default_power_limit "$1")"
	nvidia-settings --assign="[gpu:$1]/GPUPowerMizerMode=2" \
	                --assign="[gpu:$1]/GPUGraphicsClockOffsetAllPerformanceLevels=0" \
	                --assign="[gpu:$1]/GPUMemoryTransferRateOffsetAllPerformanceLevels=0"
}

# The main method of the program
main() {
	if [ $# -le 0 ]; then
		# Process all config files
		# shellcheck disable=SC2043
		for file in /etc/nvidia-oc.conf; do
			process_file "$file"
		done
	fi
	
	for arg; do
		case "$arg" in -h|--help)
			_print_help
			return
		esac
	done
	
	while [ $# -gt 0 ]; do
		case "$1" in
			-f|--file)
				if [ $# -lt 2 ]; then
					echo 'Error: missing filename for --file argument' 1>&2
					exit 1
				fi
				shift
				process_file "$1"
				;;
			-f*)
				process_file "${1#-f}"
				;;
			--file=*)
				process_file "${1#--file=}"
				;;
			--reset)
				list_gpu_ids |\
					while IFS=, read -r id; do
						reset_gpu_params "$id"
					done
				;;
			*)
				printf '%s\n' "Error: invalid option: $1" 1>&2
				exit 1
				;;
		esac
		shift
	done
}

main ${1+"$@"}
