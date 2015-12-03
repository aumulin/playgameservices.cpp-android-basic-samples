#!/usr/bin/env bash
set -eua

declare result=0
declare -r required_vars=( \
  ANDROID_HOME \
  NDK_ROOT \
  NDK_MODULE_PATH )

echo Checking Environment... >&2

# Check that all of the required environment variables are set, and
# point to valid paths.
#
for varname in ${required_vars[@]}; do
  echo "Check ${varname}"
done

[[ ${result} -ne 0 ]] && exit ${result}

# Now check the subdirectories and files we'll actually be using
# to make sure they all exist.
#
declare -r lib_rel_path="/extras/google/google_play_services/libproject/\
google-play-services_lib"

# Paths to check
declare -r required_paths=( \
  "${ANDROID_HOME}/tools/android" \
  "${NDK_ROOT}/ndk-build" \
  "${ANDROID_HOME}/${lib_rel_path}/project.properties"
  "${NDK_MODULE_PATH}/gpg-cpp-sdk/android/lib"
  "./AndroidManifest.xml"
  "./jni/Android.mk" )

# (Hopefully) helpful note to be displayed if a path check fails. Keep in
# sync with the "required_paths" array above.
declare -r remedies=( \
  "Be sure ANDROID_HOME points to the location of a valid Android SDK." \
  "Be sure NDK_ROOT points to the location of a valid Android NDK." \
  "Is the Play Games Services SDK package installed?" \
  "Have you downloaded and installed the Play Games Services SDK for C++?" \
  "Run this script from your project root." \
  "Is this an NDK project?" )

declare -i i=0
for path in ${required_paths[@]}; do
    if [[ ! -e "${path}" ]]; then
      echo "ERROR: ${path} does not exist" >&2
      echo "       ${remedies[i]}" >&2
      result=1
    fi
    i=i+1
done

# Make sure ant is installed.
if [[ -z `which ant` ]]; then
  echo "ERROR: Can't find ant on the PATH. Please (re)install ant." >&2
  result=1
fi

if [[ ${result} -ne 0 ]]; then
  echo "Environment incorrect; aborting" >&2
  exit ${result}
fi

echo Environment OK >&2

declare -x mode=${1:-debug}

declare -r android_tool="${ANDROID_HOME}/tools/android"
declare -r ndk_build="${NDK_ROOT}/ndk-build"
declare -r lib_project="${ANDROID_HOME}/${lib_rel_path}"
declare -r android_support_v4="${ANDROID_HOME}/extras/android/support/v4/\
android-support-v4.jar"

>&2 echo Preparing projects...
declare -r private_lib=".gpg-lib"

# Write out the local.properties file; replace the current one.
echo "# GENERATED by build_sample.sh -- do not modify." > local.properties
echo "sdk.dir=${ANDROID_HOME}" >> local.properties
echo "gpg.lib=${private_lib}" >> local.properties
${android_tool} update project --path .

#
# Get a private copy of the library project
#
function cleanup() {
  rm -rf ${private_lib}
}
# clean before copying to ensure no garbage is left behind...
cleanup
# ...and make sure *this* script leaves no garbage behind, either.
trap cleanup EXIT

# Copy the lib project and run "android update lib-project" on it.
# This requires a target, which apparently needs to be android-10.
cp -r ${lib_project} ${private_lib}
mkdir  -p libs
cp -f ${android_support_v4} ./libs

${android_tool} update lib-project --path ${private_lib} --target android-22

#
# At last, build!
#
echo Building... >&2
${ndk_build}
ant ${mode}

echo Done >&2
