#!/bin/sh
#
# refactored from genbranding.pl
# (c) 2017 jw@owncloud.com
#

# Usage: clienttar themetar [outvars.sh]
# shell variables describing the branding are saved into outvars.sh
# if specified.  The output tar is placed in the same directory as outvars.sh 
# (default current working directory)

clienttar=$1
themetar=$2
outfile=$3	# store shell variables from config.pgand OEM.make
outputsuffix=tar.bz2
outputtar="tar jcf"
outputdir=$(dirname $outfile)

client=$(basename $clienttar | sed -e 's|.tar.*$||')
theme=$(basename $themetar | sed -e 's|.tar.*$||')
if [ "$theme" = 'ownCloud' ]; then
	echo "Creating the original ownCloud package tarball!"
	newname=$(echo $client | tr '[:upper:]' '[:lower:]')
else
	# note: no -client suffix. works with setup_all_oem_clients.pl
	# note that we add a - here.
	newname=$(echo $client | sed -e "s/^client/$theme/i" -e "s/^owncloud/$theme/i")
fi

tmpdir=tmp$$
rm -rf $tmpdir; mkdir -p $tmpdir
/bin/tar xif $clienttar --force-local -C $tmpdir
if [ "$newname" != "$client" ]; then
	mv $tmpdir/$client $tmpdir/$newname
fi
echo newname is $newname
tarwild="/bin/tar --wildcards --force-local -xif $themetar -C $tmpdir/$newname"
$tarwild '*/mirall'     2>/dev/null && themed=mirall
$tarwild '*/syncclient' 2>/dev/null && themed=syncclient
if [ -z "$themed" ]; then
	echo "failed to extract one of these:"
	echo $tarwild '*/mirall' 
	echo $tarwild '*/syncclient' 
	rm -rf $tmpdir
	exit 1
fi
$outputtar $outputdir/$newname.$outputsuffix -C $tmpdir $newname

if [ "$theme" = 'ownCloud' ]; then
	cmakefile=OWNCLOUD.cmake
	compile_hint=""
else
	cmakefile=$theme/$themed/OEM.cmake
	compile_hint="cd src; cmake -DOEM_THEME_DIR=\$PWD/../$theme/$themed"
fi

if [ -n "$outfile" ]; then
  echo "tarname=\"$newname.$outputsuffix\"" > $outfile
  echo "theme=\"$theme\"" >> $outfile
  # json to bash syntax
  sed -e 's@^\s*@@' -e 's@^\s*,\s*@@' -e 's@\s*=>\s@=@' -e 's@",\s*$@"@' -e 's@",\s*#.*$@"@' < $tmpdir/$newname/$theme/$themed/package.cfg >> $outfile
  # cmake to bash syntax
  sed -ne 's@\s\s*"@="@' -e 's@\s\s*\${@=${@' -e 's@\s*)\s*$@@' -e 's@\s*)\s*#.*$@@' -e 's@\s*CACHE string .*$@@i' -e 's@^set(\s*@@p' < $tmpdir/$newname/$cmakefile >> $outfile
  echo "$outfile written."
  test -n "$compile_hint" && echo "compile_hint=\"$compile_hint\"" >> $outfile
fi
rm -rf $tmpdir

if [ -z "$outfile" ]; then
  echo "Output archive:"
  du -sh $newname.$outputsuffix
  echo ""
  test -n "$compile_hint" && echo "Hint: compile with $compile_hint ..."
  exit 0
fi
