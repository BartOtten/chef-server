#!/bin/bash
#
# Build you some jenkins
#

set -e
set -x

# Check whether a command exists - returns 0 if it does, 1 if it does not
exists()
{
  if command -v $1 &>/dev/null
  then
    return 0
  else
    return 1
  fi
}

usage()
{
  echo >&2 \
  "usage: $0 [-p project_name]"
}

# Get command line arguments
while getopts :p: opt
do
  echo $opt
  case "$opt" in
    p)  project_name="$OPTARG";;
    [\?]|[\:]) usage; exit 1;;
  esac
done

if [ -z $project_name ]
then
  usage
  exit 1
fi

# create the build timestamp file for fingerprinting if it doesn't exist (manual build execution)
if [ ! -f build_timestamp ]
then
  date > build_timstamp
  echo "$BUILD_TAG / $BUILD_ID" > build_timestamp
fi

rm -f $WORKSPACE/pkg/*
rm -f $WORKSPACE/src/*

mkdir -p chef-solo/cache

export PATH=/usr/local/bin:/opt/ruby1.9/bin:$PATH

# ensure bundler is installed
if ! exists bundle;
then
  sudo gem install bundler --no-ri --no-rdoc
fi

if [ "$CLEAN" = "true" ]; then
  sudo rm -rf "/opt/${project_name}" || true
  sudo mkdir -p "/opt/${project_name}" && sudo chown jenkins-node "/opt/${project_name}"
  sudo rm -r /var/cache/omnibus/pkg/* || true
  sudo rm /var/cache/omnibus/build/*/*.manifest || true
  sudo rm pkg/* || true
  bundle update
else
  bundle install
fi

# Omnibus build server prep tasks, including build ruby
sudo -i env OMNIBUS_GEM_PATH=$(bundle show omnibus) chef-solo -c $(pwd)/jenkins/solo.rb -j $(pwd)/jenkins/dna.json -l debug

# copy config into place
cp omnibus.rb.example omnibus.rb

# Aaand.. new ruby
export PATH=/usr/local/bin:$PATH
if [ "$CLEAN" = "true" ]; then
  bundle update
else
  bundle install
fi

rake "projects:${project_name}"

# Sign the package on some platforms:
if exists rpm;
then
  sudo -i $(pwd)/jenkins/sign-rpm "foo" $(pwd)/pkg/*rpm
fi