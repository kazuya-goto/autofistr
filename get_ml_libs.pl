#!/usr/bin/env perl
while(<>) {
    if(/Trilinos_PACKAGE_LIST/){
        s/^.*\"(.*)\".*$/$1/;
        $_ = lc $_;
        @_=split(/;/);
        @_=grep $_ ne "teuchos", @_;
        print "-l",join(" -l",@_);
        exit 0;
    }
}
