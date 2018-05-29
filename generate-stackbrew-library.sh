#!/usr/bin/env bash
#
#/**
# * Licensed to the Apache Software Foundation (ASF) under one
# * or more contributor license agreements.  See the NOTICE file
# * distributed with this work for additional information
# * regarding copyright ownership.  The ASF licenses this file
# * to you under the Apache License, Version 2.0 (the
# * "License"); you may not use this file except in compliance
# * with the License.  You may obtain a copy of the License at
# *
# *     http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# */

# This script generates a manifest compatible with the expectations set forth
# by docker-library/official-images.
#
# It is not compatible with the version of Bash currently shipped with OS X due
# to the use of features introduced in Bash 4.

set -eu

declare -A aliases=(
    [4.5.1]='4.5'
    [4.6.2]='4.6'
    [4.7.0]='4.7 latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )

# get the most recent commit which modified any of "$@"
fileCommit() {
    git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
    local dir="$1"; shift
    (
        cd "$dir"
        fileCommit \
       	Dockerfile \
        $(git show HEAD:./Dockerfile | awk '
            toupper($1) == "COPY" {
                for (i = 2; i < NF; i++) {
                    print $i
                }
            }
        ')
    )
}

cat <<-EOH
# this file is generated via https://github.com/asfbookkeeper-ecosystem/docker-bookkeeper/blob/$(fileCommit "$self")/$self
Maintainers: Apache BookKeeper <dev@bookkeeper.apache.org>
GitRepo: https://github.com/asfbookkeeper-ecosystem/docker-bookkeeper.git
EOH

# prints "$2$1$3$1...$N"
join() {
    local sep="$1"; shift
    local out; printf -v out "${sep//%/%%}%s" "$@"
    echo "${out#$sep}"
}

for version in "${versions[@]}"; do
    commit="$(dirCommit "$version")"

    fullVersion="$(git show "$commit":"$version/Dockerfile" | awk '$1 == "ENV" && $2 == "BK_VERSION" { print $3; exit }')"

    versionAliases=( $fullVersion )
    if [ "$version" != "$fullVersion" ]; then
        versionAliases+=( $version )
    fi
    versionAliases+=( ${aliases[$version]:-} )

    echo
    cat <<-EOE
		Tags: $(join ', ' "${versionAliases[@]}")
		GitCommit: $commit
		Directory: $version
	EOE
done
