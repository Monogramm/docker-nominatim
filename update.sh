#!/bin/bash
set -eo pipefail

declare -A compose=(
	[debian]='debian'
	[alpine]='alpine'
)

declare -A base=(
	[debian]='debian'
	[alpine]='alpine'
)

declare -A ubuntu=(
	[2.5]='trusty'
	[3.0]='xenial'
	[3.1]='xenial'
	[3.2]='bionic'
	[3.3]='bionic'
	[3.4]='focal'
	[3.5]='focal'
	[3.6]='focal'
)

declare -A extra=(
	[2.5]=''
	[3.0]=''
	[3.1]=''
	[3.2]=''
	[3.3]=''
	[3.4]='"postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION}-scripts"'
	[3.5]='"postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION}-scripts"'
	[3.6]='"postgresql-${POSTGRES_VERSION}-postgis-${POSTGIS_VERSION}-scripts"'
)

declare -A postgres=(
	[2.5]='9.3'
	[3.0]='9.5'
	[3.1]='9.5'
	[3.2]='11'
	[3.3]='11'
	[3.4]='12'
	[3.5]='12'
	[3.6]='12'
)

declare -A postgis=(
	[2.5]='2.1'
	[3.0]='2.2'
	[3.1]='2.2'
	[3.2]='2.4'
	[3.3]='2.5'
	[3.4]='3'
	[3.5]='3'
	[3.6]='3'
)

variants=(
	debian
	#alpine
)

min_version='2.5'
dockerLatest='1.4'


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

dockerRepo="monogramm/docker-nominatim"
# Retrieve automatically the latest versions
latests=( $( curl -fsSL 'https://api.github.com/repos/osm-search/Nominatim/tags' |tac|tac| \
	grep -oE '[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+' | \
	sort -urV ) )
#latests=(
#	2.5
#	3.0
#	3.1
#	3.2
#	3.3
#	3.4
#	3.5
#)

# Remove existing images
echo "reset docker images"
#find ./images -maxdepth 1 -type d -regextype sed -regex '\./images/[[:digit:]]\+\.[[:digit:]]\+' -exec rm -r '{}' \;
rm -rf ./images/*

echo "update docker images"
travisEnv=
for latest in "${latests[@]}"; do
	version=$(echo "$latest" | cut -d. -f1-2)

	# Only add versions >= "$min_version"
	if version_greater_or_equal "$version" "$min_version"; then

		for variant in "${variants[@]}"; do
			# Create the version directory with a Dockerfile.
			dir="images/$version/$variant"
			if [ -d "$dir" ]; then
				continue
			fi
			echo "Updating $latest [$version-$variant]"
			mkdir -p "$dir"

			template="Dockerfile.${base[$variant]}"
			cp "template/$template" "$dir/Dockerfile"
			cp \
				"template/entrypoint.sh" \
				"template/init.sh" \
				"template/start.sh" \
				"template/startapache.sh" \
				"template/startpostgres.sh" \
				"template/local.php" \
				"template/nominatim-apache.conf" \
				"$dir/"

			cp "template/.dockerignore" "$dir/.dockerignore"
			cp -r "template/hooks" "$dir/"
			cp -r "template/test" "$dir/"
			cp "template/.env" "$dir/.env"
			cp "template/docker-compose_${compose[$variant]}.yml" "$dir/docker-compose.test.yml"

			# Replace the variables.
			sed -ri -e '
				s/%%VARIANT%%/-'"$variant"'/g;
				s/%%VERSION%%/v'"$latest"'/g;
				s/%%UBUNTU_VERSION%%/'"${ubuntu[$version]}"'/g;
				s/%%POSTGRES_VERSION%%/'"${postgres[$version]}"'/g;
				s/%%POSTGIS_VERSION%%/'"${postgis[$version]}"'/g;
				s/%%EXTRA%%/'"${extra[$version]}"'/g;
			' "$dir/Dockerfile"

			sed -ri -e '
				s|DOCKER_TAG=.*|DOCKER_TAG='"$version"'|g;
				s|DOCKER_REPO=.*|DOCKER_REPO='"$dockerRepo"'|g;
			' "$dir/hooks/run"

			# Create a list of "alias" tags for DockerHub post_push
			if [ "$latest" = "$dockerLatest" ]; then
				export DOCKER_TAG="$variant"
			else
				export DOCKER_TAG="$latest-$variant"
			fi
			echo "${DOCKER_TAG} " > "$dir/.dockertags"

			# Add Travis-CI env var
			travisEnv='\n    - VERSION='"$version"' VARIANT='"$variant$travisEnv"

			if [[ "$1" == 'build' ]]; then
				export DOCKER_TAG="$latest-$variant"
				export IMAGE_NAME=${DOCKER_REPO}:${DOCKER_TAG}
				export DOCKERFILE_PATH=Dockerfile
				cd "$dir"
				echo "Build Dockerfile for ${DOCKER_TAG}"
				./hooks/build
				echo "Test docker image for ${DOCKER_TAG}"
				./hooks/pre_test
				docker-compose -f docker-compose.test.yml up sut
				docker-compose -f docker-compose.test.yml down
				cd -
			fi
		done
	fi

done

# update .travis.yml
travis="$(awk -v 'RS=\n\n' '$1 == "env:" && $2 == "#" && $3 == "Environments" { $0 = "env: # Environments'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
