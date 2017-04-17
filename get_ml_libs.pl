#!/usr/bin/env perl
while(<>) {
    if(/ML_LIBRARIES/){
        s/^.*\"(.*)\".*$/$1/;
        @_=split(/;/);
        print "-l",join(" -l",@_);
        exit 0;
    }
}
