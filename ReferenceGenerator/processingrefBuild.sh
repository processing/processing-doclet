#!/bin/sh

echo "[REFERENCE GENERATOR] Booting up..."

# PROCESSING_SRC_PATH=./test
PROCESSING_SRC_PATH=../../processing4/core/src
PROCESSING_LIB_PATH=../../processing4/java/libraries
PROCESSING_VIDEO_PATH=../../processing-video
PROCESSING_SOUND_PATH=../../processing-sound

DOCLET_PATH=bin/:lib/org.json.jar
SOURCE_PATH=../../processing4/core/bin
REFERENCES_OUT_PATH=../../processing-website/content/references/translations/en
CLASS_PATH="$PROCESSING_SRC_PATH/../library/*:$PROCESSING_LIB_PATH/serial/library/*:$PROCESSING_LIB_PATH/io/library/*:$PROCESSING_LIB_PATH/net/library/*:$PROCESSING_VIDEO_PATH/library/*:$PROCESSING_SOUND_PATH/library/*"

# GENERATE REFERENCE ENTRIES AND INDEX THROUGH JAVADOC - BY DAVID WICKS

echo "[REFERENCE GENERATOR] Source Path :: $PROCESSING_SRC_PATH"
echo "[REFERENCE GENERATOR] Library Path :: $PROCESSING_LIB_PATH"

# You can pass one argument "sound" or "video" to generate those libraries separately
# or "processing" to generate the core without the sound and video libraries
# if there is no argument it will generate everything
if [ $# -eq 0 ]
  then
    echo "No arguments supplied, generating everything"
    echo "[REFERENCE GENERATOR] Removing previous version of the ref..."
    FOLDERS="$PROCESSING_SRC_PATH/processing/core/*.java \
        	$PROCESSING_SRC_PATH/processing/awt/*.java \
    			$PROCESSING_SRC_PATH/processing/data/*.java \
    			$PROCESSING_SRC_PATH/processing/event/*.java \
    			$PROCESSING_SRC_PATH/processing/opengl/*.java \
    			$PROCESSING_LIB_PATH/io/src/processing/io/*.java \
    			$PROCESSING_LIB_PATH/net/src/processing/net/*.java \
    			$PROCESSING_LIB_PATH/serial/src/processing/serial/*.java \
    			$PROCESSING_VIDEO_PATH/src/processing/video/*.java \
    			$PROCESSING_SOUND_PATH/src/processing/sound/*.java"
  elif [ $1 = "processing" ]
  then
    echo "Generating processing references"
    echo "[REFERENCE GENERATOR] Removing previous version of the ref..."
    FOLDERS="$PROCESSING_SRC_PATH/processing/core/*.java \
          $PROCESSING_SRC_PATH/processing/data/*.java \
          $PROCESSING_SRC_PATH/processing/event/*.java \
          $PROCESSING_SRC_PATH/processing/opengl/*.java \
          $PROCESSING_LIB_PATH/io/src/processing/io/*.java \
          $PROCESSING_LIB_PATH/net/src/processing/net/*.java \
          $PROCESSING_LIB_PATH/serial/src/processing/serial/*.java"
  elif [ $1 = "video" ]
  then
  	echo "Generating video library"
  	echo "[REFERENCE GENERATOR] Removing previous version of the ref..."
  	FOLDERS="$PROCESSING_VIDEO_PATH/src/processing/video/*.java"
  elif [ $1 = "sound" ]
  then
  	echo "Generating sound library"
  	echo "[REFERENCE GENERATOR] Removing previous version of the ref..."
  	FOLDERS="$PROCESSING_SOUND_PATH/src/processing/sound/*.java"
  else
    echo "Option '$1' not valid. Should be 'processing', 'sound' or 'video'"
    exit 1
fi

if [ $# -eq 0 -o "$1" = 'sound' ]; then
	# check for jq and sponge

	HASDEPENDENCIES=0
	if !command -v jq &> /dev/null
	then
		HASDEPENDENCIES=1
	fi
	if !command -v sponge &> /dev/null
	then
		HASDEPENDENCIES=1
	fi
	if [ $HASDEPENDENCIES -eq 1 ]; then
		echo "Could not find dependencies 'jq' and/or 'sponge' required to build Sound library reference, please run: brew/apt-get install jq moreutils"
		exit 1
	fi

	# sound library reference needs a clean slate to generate subclass 
	# documentation correctly
	rm -f $REFERENCES_OUT_PATH/sound/*
fi

echo "[REFERENCE GENERATOR] Generating new javadocs..."
javadoc -doclet ProcessingWeblet \
        -docletpath $DOCLET_PATH \
        --source-path $SOURCE_PATH \
        --class-path $CLASS_PATH \
        -public \
	-templatedir ../templates \
	-examplesdir ../../content/api_en \
	-includedir ../../content/api_en/include \
	-imagedir images \
	-encoding UTF-8 \
  $FOLDERS \
	-noisy


# move into `processing-website` and run npx prettier
if command -v npx &> /dev/null
then
	echo
	echo 'Calling `npx prettier`'
	echo
	npx --yes prettier --write $REFERENCES_OUT_PATH || exit 1 # TODO remove translations/en from path?
fi

# DO POST-PROCESSING FOR THE SOUND LIBRARY (move reference entries from superclasses down into subclasses)

function CopyAndReplace ()
{
	# remove class file which was only needed to trigger generation of the per-method .json files
	if [ ! -f "$superclass.json" ]; then
		echo "Couldn't find superclass files, are you running this script a second time since generating the doclets?"
		exit 1
	fi
	rm "$superclass.json"

	echo "$superclass"
	for infile in $superclass*; do
		# for every _method_.json: create a copy for every subclass
		echo " - $infile"
		for subclass in $subclasses; do
			outfile=`echo $infile | sed "s/$superclass/$subclass/"`
			if [ -f $outfile ]; then
				echo "   . $outfile already exists, subclass must have its own @webref documentation"
			else
				echo "   > $outfile"

				# append method descriptions to subclass
				jq --slurpfile method $infile --arg anchor "`basename $outfile .json`" '.methods += [{ "anchor": $anchor, "name": $method[0].name, "desc": $method[0].description}]' $subclass.json | sponge $subclass.json

				# change @webref (sub)categories
			  if [ "$superclass" = "SoundObject" ]; then
					# fix discrepancy between class name and webref category name
					prettyclass=$subclass
					if [ "$subclass" = "Oscillator" ]; then
						prettyclass="Oscillators" # fix category name
				  elif [ "$subclass" = "AudioIn" ]; then
				  	prettyclass="I/O"
				  fi

					sed -e "s,\"category\": \"SoundObject\",\"category\": \"$prettyclass\"," \
							-e "s/\"subcategory\": \"\"/\"subcategory\": \"$subclass\"/" \
							-e "s/\"classanchor\": \"$superclass\"/\"classanchor\": \"$subclass\"/" \
								$infile > $outfile
			  else
					# all concrete classes simply replace the subcategory
					sed -e "s/\"subcategory\": \"$superclass\"/\"subcategory\": \"$subclass\"/" \
							-e "s/\"classanchor\": \"$superclass\"/\"classanchor\": \"$subclass\"/" \
								$infile > $outfile
			  fi
			fi
		done
		# remove superclass method file
	  rm "$infile"
	done
	echo
	# sort methods listing in class files alphabetically
	for subclass in $subclasses; do
		jq '.methods|=sort_by(.name)' $subclass.json | sponge $subclass.json
	done
}

if [ $# -eq 0 -o "$1" = 'sound' ]; then
	echo
	echo "Performing post-processing of Sound library reference"
	echo
	THISDIR=`pwd`
	cd $REFERENCES_OUT_PATH/sound
	superclass=SoundObject subclasses="AudioIn Noise Oscillator" CopyAndReplace # TODO AudioSample ??

	# superclass=AudioSample subclasses="SoundFile" CopyAndReplace
	superclass=Oscillator subclasses="Pulse SawOsc SinOsc SqrOsc TriOsc" CopyAndReplace
	superclass=Noise subclasses="BrownNoise PinkNoise WhiteNoise" CopyAndReplace

	superclass=Effect subclasses="AllPass Delay Filter Reverb" CopyAndReplace
	superclass=Filter subclasses="BandPass HighPass LowPass" CopyAndReplace

	superclass=Analyzer subclasses="Amplitude BeatDetector FFT PitchDetector Waveform" CopyAndReplace
	cd "$THISDIR"
	echo "Sound library post-processing completed."
fi


if ! command -v npx &> /dev/null
then
	echo 'WARNING: npx is not installed, so could not run `npx prettier --write content/references`'
	echo '`git diff` might show lots of modified files that only differ in JSON formatting, not content.'
	exit 1
fi
