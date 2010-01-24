#!/usr/bin/perl
#
# DotdeeFS by Stefan Tomanek <stefan@pico.ruhr.de>
#
# converts directories of the format /foo.d/... into single files /foo

package DotdeeFS;

use strict;
use Fuse;
use POSIX qw(ENOENT ENOSYS EEXIST EPERM O_RDONLY O_RDWR O_APPEND O_CREAT);
use Fcntl qw(:mode);
use IO::File;

# data source directory
my $src = shift @ARGV;
# mountpoint
my $dst = shift @ARGV;

sub getattr {
    my ($file) = @_;
    my $item = $file;
    my $dir2file = 0;
    unless ($item eq "/") {
        $item =~ s/\/$//;
        $item .= '.d/';
        $dir2file = 1;
    }
    my @orig = stat($src.$item);
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)
        = @orig;
    my @new = @orig;
    $new[3] = 1;
    # convert directory mode to file mode
    if ($dir2file) {
        my $perms = ($mode & 07777);
        $new[2] = ( S_IFREG | $perms );
    }
    return @new;
}

sub getdir {
    my ($file) = @_;
    
    my @files;
    if ($file eq "/") {
        opendir(my $dh, $src);
        @files = grep { s/\.d$// } readdir($dh);
        closedir $dh;
        push @files, 0;
    }
    return @files;
}

sub file_parts {
    my ($file) = @_;
    
    my $dirname = $src.$file.".d/";
    opendir(my $dh, $dirname);
    my @parts = sort grep { -f $_ } map { $dirname.$_ } readdir($dh);
    closedir $dh;

    return @parts;
}

sub concatenate_file {
    my ($file) = @_;
    my $data = "";
    my @parts = file_parts($file);
    # read all parts and concatenate the data
    for my $p (@parts) {
        # read the complete file
        local $/;
        my $fh = new IO::File($p, "r");
        $data .= <$fh>; 
        $fh->close();
    }
    return $data;
}

sub read {
    my ($file, $size, $offset) = @_;
    my $data = concatenate_file($file);
    return substr($data, $offset, $size);
}

Fuse::main(
    mountpoint  => $dst,
    getattr     => \&getattr,
    getdir      => \&getdir,
    read        => \&read,
    threaded    => 0,
    debug       => 0
);
