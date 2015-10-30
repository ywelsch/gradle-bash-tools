GRADLE_DEFAULT_FLAGS="--daemon"

_upsearch() # adapted from https://gist.github.com/lsiden/1577473
{
  local file_to_search=$1
  local curdir=`pwd`

  while [[ "`pwd`" != '/' ]]; do
    if [ -f "${file_to_search}" ]; then
      pwd
      cd "${curdir}"
      return 0
    fi
    cd ..
  done
  cd "${curdir}"
  return 1
}

_find_gradle_projectdir()
{
  _upsearch "build.gradle"
}

_find_gradle_rootprojectdir()
{
  _upsearch "settings.gradle"
}

_run_gradle()
{
  local gradle_root_project_dir=`_find_gradle_rootprojectdir`
  local gradle_project_dir=`_find_gradle_projectdir`
  if [ -z "$gradle_project_dir" ]; then
    echo "Gradle project directory not found" 1>&2
    return 1
  fi
  # Use gradle wrapper if available
  local gradle_command="${gradle_root_project_dir}/gradlew"
  if [ ! -f "${gradle_command}" ]; then
    gradle_command="${gradle_project_dir}/gradlew"
    if [ ! -f "${gradle_command}" ]; then
      gradle_command="gradle"
    fi
  fi
  "${gradle_command}" -p "${gradle_project_dir}" "$@"
}

alias gr="_run_gradle ${GRADLE_DEFAULT_FLAGS}"


_gradle_complete()
{
  local singledash='-? -h -a -b -c -D -d -g -I -i -m -P -p -q -S -s -t -u -v -x'
  local doubledash='--help  --no-rebuild --all --build-file --settings-file --console --continue --configure-on-demand --system-prop --debug --gradle-user-home --gui --init-script --info --dry-run --offline --project-prop --project-dir --parallel --max-workers --profile --project-cache-dir --quiet --recompile-scripts --refresh-dependencies --rerun-tasks --full-stacktrace --stacktrace --continuous --no-search-upwards --version --exclude-task --no-color --parallel-threads --daemon --foreground --no-daemon --stop'

  # current word
  local cur
  _get_comp_words_by_ref -n : cur

  case "${cur}" in
      --*)
      COMPREPLY=( $(compgen -S " " -W "${doubledash}" -- ${cur}) )
    ;;
    -*)
      COMPREPLY=( $(compgen -S " " -W "${singledash}" -- ${cur}) )
    ;;
    *)
      local gradle_root_project_dir=`_find_gradle_rootprojectdir`
      if [ -z "${gradle_root_project_dir}" ]; then
        # fallback to build.gradle
        gradle_root_project_dir=`_find_gradle_projectdir`
        if [ -z "${gradle_root_project_dir}" ]; then
          return 1
        fi
      fi

      local folderSha
      if builtin command -v md5 > /dev/null; then
        folderSha=$(md5 -q -s "${gradle_root_project_dir}")
      elif builtin command -v md5sum > /dev/null ; then
        folderSha=$(printf '%s' "${gradle_root_project_dir}" | md5sum | awk '{print $1}')
      else
        echo "Neither md5 nor md5sum were found in the PATH" 1>&2
        return 1
      fi

      if [ ! -f "${HOME}/.gradle/bash/${folderSha}/gradle-autocomplete" ]; then
        return 1
      fi

      if [ ! -f "${HOME}/.gradle/bash/${folderSha}/gradle-projects" ]; then
        return 1
      fi

      local completionDir="${HOME}/.gradle/bash/${folderSha}"
      local commands=$(cat "${completionDir}/gradle-autocomplete")
      # file that maps project path to relative directory
      # transform relative directory path to absolute path
      local projectmappings=$(cat "${completionDir}/gradle-projects" \
        | awk -F '=' "{print \$1\"=${gradle_root_project_dir}/\"\$2}")

      # find current project path based on current directory, searching upward
      local curdir=`pwd`
      local foundmapping

      # assumes subtrees comes after root
      while [[ "`pwd`" != '/' ]]; do
        foundmapping=$(printf '%s' "${projectmappings}" | grep -m 1 -F "`pwd`")
        if [ ! -z "${foundmapping}" ]; then
          break
        fi
        cd ..
      done
      cd "${curdir}"

      # path to the project that our current directory corresponds to
      local cdprojectpath=$(printf '%s' "$foundmapping" | awk -F '=' '{print $1}')

      if [ "${cdprojectpath}" != ":" ]; then
          cdprojectpath="${cdprojectpath}:"
      fi
      # cdprojectpath always ends with ":"

      # simulate root project path if current command starts with ":"
      case "${cur}" in
          :*)
          cdprojectpath=":"
          # remove leading colons ::::: from cur (if there is more than one)
          cur=$(printf '%s' "${cur}" | sed -E 's/^:*([^:]*.*)$/\1/')
      esac
      # cdprojectpath always ends with ":"
      # cur does not start with ":"

      # project path that we are selecting by $cur (everything before the last colon)
      local currprojectpath=$(printf '%s' "$cur" | grep ':' | sed -E 's/^(.*):[^:]*$/\1/')
      # currprojectpath does not start with ":" and never ends with ":"
      # currprojectpath can also be empty

      # set cur to everything behind last colon in cur
      cur="${cur#$currprojectpath}"
      cur="${cur#:}" # remove leading ":"

      # construct project path based on path of current directory and path selected by cur
      local totalpath
      if [ "x${currprojectpath}" == "x" ]; then # if $currprojectpath is empty
        totalpath="${cdprojectpath}"
      else
        totalpath="${cdprojectpath}${currprojectpath}:"
      fi

      # select subtree of commands that begins with totalpath
      commands=$(printf '%s' "${commands}" | grep "^${totalpath}")
      commands=$(printf '%s' "${commands}" | sed -E "s/^${totalpath}(.*)$/\1/")

      # distinguish subprojects and tasks based on colon
      local subprojects=$(printf '%s' "${commands}" | grep ':' | awk -F ':' '{print $1}' | uniq)
      local tasks=$(printf '%s' "${commands}" | grep -v ':' | awk -F ':' '{print $1}')

      declare -a subprojectsCompl
      declare -a tasksCompl
      local IFS=$'\t\n'

      local subprojectsCompl=$(compgen -S ':' -o nospace -W "${subprojects}" -- ${cur})
      local tasksCompl=$(compgen -S " " -W "${tasks}" -- ${cur})
      COMPREPLY=( ${subprojectsCompl[@]} ${tasksCompl[@]} )

      __ltrim_colon_completions "$cur"
    ;;
  esac
}

complete -o nospace -F _gradle_complete gr
