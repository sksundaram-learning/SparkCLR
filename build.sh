#!/bin/bash

export FWDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export SPARKCLR_HOME="$FWDIR/run"
echo "SPARKCLR_HOME=$SPARKCLR_HOME"

if [ -d "$SPARKCLR_HOME" ];
then
  echo "Delete existing $SPARKCLR_HOME ..."
  rm -r -f "$SPARKCLR_HOME"
fi

[ ! -d "$SPARKCLR_HOME" ] && mkdir "$SPARKCLR_HOME"
[ ! -d "$SPARKCLR_HOME/bin" ] && mkdir "$SPARKCLR_HOME/bin"
[ ! -d "$SPARKCLR_HOME/data" ] && mkdir "$SPARKCLR_HOME/data"
[ ! -d "$SPARKCLR_HOME/lib" ] && mkdir "$SPARKCLR_HOME/lib"
[ ! -d "$SPARKCLR_HOME/samples" ] && mkdir "$SPARKCLR_HOME/samples"
[ ! -d "$SPARKCLR_HOME/scripts" ] && mkdir "$SPARKCLR_HOME/scripts"

echo "Assemble SparkCLR Scala components"
pushd "$FWDIR/scala"

# clean the target directory first
mvn clean -q
[ $? -ne 0 ] && exit 1

# Note: Shade-plugin helps creates an uber-package to simplify SparkCLR job submission;
# however, it breaks debug mode in IntellJ. A temporary workaroud to add shade-plugin
# only in build.cmd to create the uber-package.
cp pom.xml /tmp/pom.xml.original
sed -i -e '/<\!--OTHER PLUGINS-->/r other-plugin.xml' pom.xml
# build the package
mvn package -q
[ $? -ne 0 ] && exit 1
# After uber package is created, restore Pom.xml
cp /tmp/pom.xml.original pom.xml

if [ $? -ne 0 ]
then
	echo "Build SparkCLR Scala components failed, stop building."
	popd
	exit 1
fi
echo "SparkCLR Scala binaries"
cp target/*.jar "$SPARKCLR_HOME/lib/"
popd

# Any .jar files under the lib directory will be copied to the staged runtime lib tree.
if [ -d "$FWDIR/lib" ];
then
  echo "Copy extra jar library binaries"
  for g in `ls $FWDIR/lib/*.jar`
  do
    echo "$g"
    cp "$g" "$SPARKCLR_HOME/lib/"
  done
fi

echo "Assemble SparkCLR C# components"
pushd "$FWDIR/csharp"

# clean any possible previous build first
./clean.sh

./build.sh

if [ $? -ne 0 ];
then
	echo "Build SparkCLR C# components failed, stop building."
	popd
	exit 1
fi
echo "SparkCLR C# binaries"
cp Worker/Microsoft.Spark.CSharp/bin/Release/* "$SPARKCLR_HOME/bin/"

echo "SparkCLR C# Samples binaries"
# need to include CSharpWorker.exe.config in samples folder
cp Worker/Microsoft.Spark.CSharp/bin/Release/* "$SPARKCLR_HOME/samples/"
cp Samples/Microsoft.Spark.CSharp/bin/Release/* "$SPARKCLR_HOME/samples/"

echo "SparkCLR Samples data"
cp Samples/Microsoft.Spark.CSharp/data/* "$SPARKCLR_HOME/data/"
popd

echo "Assemble SparkCLR script components"
pushd "$FWDIR/scripts"
cp *.sh  "$SPARKCLR_HOME/scripts/"
popd

echo "zip run directory"
[ ! -d "$FWDIR/target" ] && mkdir "$FWDIR/target"
pushd "$SPARKCLR_HOME"
zip -r "$FWDIR/target/run.zip" ./*
popd
