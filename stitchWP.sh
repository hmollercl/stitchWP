#!/usr/bin/env bash
########################################################################
# This script is a workaround for the lack of support from pcfman-qt   
# for wallpaper in multiple display environment. pcmanfm-qt handle all 
# the monitors as only one big monitor. This script takes the configuration from 
# pcfman-qt and replicate it in all the monitors creating a big canvas 
# and stitching the image to it. The steps are                                        
# 1) Takes the pxfman-qt configuration
# 2) It takes current display configuration from xrandr.
# 3) Create new wallpaper image repeating the original wallpaper to match the monitors
# 4) Updates the wallpaper with the created image                  
########################################################################
PROFILE="lxqt" #profile used when running pcmanfm-qt --desktop
wpNew="$HOME/.config/pcmanfm-qt/$PROFILE/stitchWP.jpg" #where stitched wallpaper is saved, extension from source file.
settingsFile="$HOME/.config/pcmanfm-qt/$PROFILE/settings.conf"
changeWP="pcmanfm-qt --set-wallpaper" #command to use to change the wallpaper, at the end the new file is concatenated to this command.

#########################################################################
#Get actual wallpaper configuration
wpFile=$(grep 'Wallpaper=' $settingsFile)
wpFile=${wpFile:10}

wpM=$(grep 'WallpaperMode=' $settingsFile)
wpM=${wpM:14}

wpBg=$(grep 'BgColor=' $settingsFile)
wpBg=${wpBg:8}

if [ $wpFile == $wpNew ]; then
	exit
fi

#Get dimensions of original image
imageInfo=$(identify $wpFile | grep -o '[1-9][0-9]*x[1-9][0-9]* ')
IFS='x'
j=0
for STRING in $imageInfo; do
	case $j in 
		0)
			wImage=$STRING;;
		1)
			hImage=$STRING;;
	esac
	j=$((j + 1))
done

case $wpM in
	tile)
		exit;;
	none)
		exit;;
esac

##############################################################################################################
# Get current display configurator
# xrandr regex, + don't have to be escaped in grep.
# xrandr | grep -oe 'current [1-9][0-9]* x [1-9][0-9]*' -oe '[1-9][0-9]*x[1-9][0-9]*+[0-9]*+[0-9]*'
XOUT=$(xrandr | grep -oe 'current [1-9][0-9]* x [1-9][0-9]*' -oe '[1-9][0-9]*x[1-9][0-9]*+[0-9]*+[0-9]*')
IFS=$'\n' #separate to lines with internal field separator
dispNumber=0
for LINE in $XOUT; do
	array[$dispNumber]=$LINE
	dispNumber=$((dispNumber + 1))
done
dispNumber=$((dispNumber - 1)) #number of displays used

#parse the total screen xinerama size.
IFS=' ' #separate to lines with internal field separator
i=0
for STRING in ${array[0]}; do
	case $i in 
		1)
			canvasW=$STRING;;
		3)
			canvasH=$STRING;;
	esac
	i=$((i + 1))
done
########################################################
#if canvas == actual image
#IF ((canvasW==wImagen) && (canvasH==hImagen))
#exit
########################################################
#Parse each screen size and position
for ((i=1; i <= $dispNumber ; i++)); do
	IFS='x'
	j=0
	for STRING in ${array[$i]}; do
		case $j in 
			0)
				w[$i]=$STRING
				;;
			1)
				IFS='+'
				k=0
				for CHUNK in $STRING; do
					case $k in 
						0)
							h[$i]=$CHUNK;;
						1)
							x[$i]=$CHUNK;;
						2)
							y[$i]=$CHUNK;;
					esac
					k=$((k + 1))
				done
		esac
		j=$((j + 1))
	done
done

case $wpM in
	stretch)
		newImage="convert -size "$canvasW"x"$canvasH" xc:"$wpBg""
		for ((i=1; i <= $dispNumber ; i++)); do
			newImage="$newImage -draw \"image over ${x[$i]},${y[$i]} ${w[$i]},${h[$i]} '"$wpFile"'\""
		done
		newImage="$newImage $wpNew"
		#echo $newImage
		eval $newImage
	;;
	fit)
		newImage="convert -size "$canvasW"x"$canvasH" xc:"$wpBg" "
		#mantain aspect ratio, it fit the screen from the inside, could not cover the whole screen background color could be seen.
		for ((i=1; i <= $dispNumber ; i++)); do	
			wRatio[$i]=$((${w[$i]} * 100 / $wImage))
			#echo ${wRatio[$i]}
			hRatio[$i]=$((${h[$i]} * 100 / $hImage))
			#echo ${hRatio[$i]}
			
			if [ ${wRatio[$i]} -lt ${hRatio[$i]} ]; then #fit horizontal, space up and down.
				Y=$(($hImage * wRatio[$i] / 100))
				Y=$((${h[$i]} - $Y))
				Y=$(($Y / 2 + y[i]))
				W=$(($wImage * wRatio[$i] / 100))
				H=$(($hImage * wRatio[$i] / 100))
				newImage="$newImage -draw \"image over ${x[$i]},$Y $W,$H '"$wpFile"'\""
			else #fit vertical, space on sides
				X=$(($wImage * hRatio[$i] / 100))
				X=$((${w[$i]} - $X))
				X=$(($X / 2 + x[i]))
				W=$(($wImage * hRatio[$i] / 100))
				H=$(($hImage * hRatio[$i] / 100))
				newImage="$newImage -draw \"image over $X,${y[$j]} $W,$H '"$wpFile"'\""
			fi
		done
		newImage="$newImage $wpNew"
		#echo $newImage
		eval $newImage
	;;
	center) #image is NOT scaled. If image is not croped n+1 could superpose x<n+1 iamge
	;;
	zoom) #image is scaled maintaining ratio, MUST cover the whole screen, pieces of image could be ot of screen.If image is not croped n+1 could superpose x<n+1 iamge
	;;
	#tile) #not needed
	#none) #not needed
esac

#Set New Wallpaper
changeWP="$changeWP $wpNew"
echo $changeWP
eval $changeWP

