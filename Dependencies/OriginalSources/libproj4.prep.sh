#! /bin/bash

# extract and clean up source files from a libproj4 RCS distro
# written on February 4, 2008 by Nathan Vander Wilt

# copy RCS files to working directory
cd libproj4
cp -r src/ src-co/
chmod -R a+r,ug+w src-co

# extract top level files (README, Makefile)
cd src-co
rm REL_*
co -f *
rm *,v

# checkout main source code and remove versioned files
cd RCS
co -f *
rm *,v

# move extracted files out of RCS directory...
mv -f * ../
cd ..
rm -r RCS

# ...and into main directory
mv -f * ../
cd ..
rm -r src-co


# remove original source directory
rm -rf src
