#!/usr/bin/env bash

set -u

hook_name="${1:-}"
if [[ -z "$hook_name" ]]; then
  printf '%s\n' "Failed to log Copilot hook: event name argument is required." >&2
  exit 1
fi

if [[ ! "$hook_name" =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
  printf '%s\n' "Failed to log Copilot hook: invalid event name '${hook_name}'." >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
log_dir="${script_dir}/../logs"
log_file="${log_dir}/copilot-hooks.jsonl"

if ! command -v awk >/dev/null 2>&1; then
  printf '%s\n' "Failed to log Copilot hook '${hook_name}': awk is required." >&2
  exit 1
fi

if ! mkdir -p -- "$log_dir"; then
  printf '%s\n' "Failed to log Copilot hook '${hook_name}': could not create the log directory." >&2
  exit 1
fi

logged_at="$(date '+%Y-%m-%dT%H:%M:%S%z')"

if ! awk \
  -v hook_name="$hook_name" \
  -v logged_at="$logged_at" \
  -v log_file="$log_file" '
function fail(message) {
  error_message = message
  return 0
}

function is_digit(character) {
  return character >= "0" && character <= "9"
}

function skip_whitespace(    character) {
  while (position <= input_length) {
    character = substr(input, position, 1)
    if (character != " " && character != "\t" &&
        character != "\r" && character != "\n") {
      break
    }
    position++
  }
}

function parse_string(    start, character, escape, hex_index, hex_character) {
  if (substr(input, position, 1) != "\"") {
    return fail("expected a string")
  }

  start = position++
  while (position <= input_length) {
    character = substr(input, position, 1)
    if (character == "\"") {
      position++
      compact = compact substr(input, start, position - start)
      return 1
    }

    if (character == "\\") {
      position++
      if (position > input_length) {
        return fail("unterminated escape sequence")
      }

      escape = substr(input, position, 1)
      if (escape == "u") {
        for (hex_index = 1; hex_index <= 4; hex_index++) {
          hex_character = substr(input, position + hex_index, 1)
          if (hex_character !~ /^[0-9A-Fa-f]$/) {
            return fail("invalid Unicode escape sequence")
          }
        }
        position += 5
        continue
      }

      if (escape !~ /^["\\\/bfnrt]$/) {
        return fail("invalid escape sequence")
      }
      position++
      continue
    }

    if (character ~ /[[:cntrl:]]/) {
      return fail("unescaped control character in string")
    }
    position++
  }

  return fail("unterminated string")
}

function parse_number(    start, character) {
  start = position
  if (substr(input, position, 1) == "-") {
    position++
  }

  character = substr(input, position, 1)
  if (character == "0") {
    position++
    if (is_digit(substr(input, position, 1))) {
      return fail("leading zero in number")
    }
  } else {
    if (character < "1" || character > "9") {
      return fail("invalid number")
    }
    while (is_digit(substr(input, position, 1))) {
      position++
    }
  }

  if (substr(input, position, 1) == ".") {
    position++
    if (!is_digit(substr(input, position, 1))) {
      return fail("invalid number fraction")
    }
    while (is_digit(substr(input, position, 1))) {
      position++
    }
  }

  character = substr(input, position, 1)
  if (character == "e" || character == "E") {
    position++
    character = substr(input, position, 1)
    if (character == "+" || character == "-") {
      position++
    }
    if (!is_digit(substr(input, position, 1))) {
      return fail("invalid number exponent")
    }
    while (is_digit(substr(input, position, 1))) {
      position++
    }
  }

  compact = compact substr(input, start, position - start)
  return 1
}

function parse_array(    character) {
  compact = compact "["
  position++
  skip_whitespace()
  if (substr(input, position, 1) == "]") {
    compact = compact "]"
    position++
    return 1
  }

  while (1) {
    if (!parse_value()) {
      return 0
    }
    skip_whitespace()
    character = substr(input, position, 1)
    if (character == "]") {
      compact = compact "]"
      position++
      return 1
    }
    if (character != ",") {
      return fail("expected comma or closing bracket")
    }
    compact = compact ","
    position++
    skip_whitespace()
  }
}

function parse_object(    character) {
  compact = compact "{"
  position++
  skip_whitespace()
  if (substr(input, position, 1) == "}") {
    compact = compact "}"
    position++
    return 1
  }

  while (1) {
    if (!parse_string()) {
      return 0
    }
    skip_whitespace()
    if (substr(input, position, 1) != ":") {
      return fail("expected colon after object key")
    }
    compact = compact ":"
    position++
    skip_whitespace()
    if (!parse_value()) {
      return 0
    }
    skip_whitespace()
    character = substr(input, position, 1)
    if (character == "}") {
      compact = compact "}"
      position++
      return 1
    }
    if (character != ",") {
      return fail("expected comma or closing brace")
    }
    compact = compact ","
    position++
    skip_whitespace()
  }
}

function parse_value(    character, literal) {
  skip_whitespace()
  character = substr(input, position, 1)

  if (character == "\"") {
    return parse_string()
  }
  if (character == "{") {
    return parse_object()
  }
  if (character == "[") {
    return parse_array()
  }
  if (character == "-" || is_digit(character)) {
    return parse_number()
  }

  literal = substr(input, position, 4)
  if (literal == "true" || literal == "null") {
    compact = compact literal
    position += 4
    return 1
  }
  if (substr(input, position, 5) == "false") {
    compact = compact "false"
    position += 5
    return 1
  }

  return fail("expected a JSON value")
}

{
  input = input $0 "\n"
}

END {
  input_length = length(input)
  position = 1

  if (!parse_value()) {
    print "Failed to log Copilot hook \047" hook_name \
      "\047: invalid JSON payload (" error_message ")." > "/dev/stderr"
    exit 1
  }

  skip_whitespace()
  if (position <= input_length) {
    print "Failed to log Copilot hook \047" hook_name \
      "\047: invalid JSON payload (unexpected trailing content)." > "/dev/stderr"
    exit 1
  }

  printf "{\"loggedAt\":\"%s\",\"hook\":\"%s\",\"payload\":%s}\n", \
    logged_at, hook_name, compact >> log_file
  if (close(log_file) != 0) {
    print "Failed to log Copilot hook \047" hook_name \
      "\047: could not write to the log file." > "/dev/stderr"
    exit 1
  }
}
'; then
  exit 1
fi
