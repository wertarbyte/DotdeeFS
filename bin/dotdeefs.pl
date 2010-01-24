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
    if ($item eq "/") {
        return stat($src);
    } else {
        return file_stats($file);
    }
}

sub file_stats {
    my ($filename) = @_;
    # we base the stat info on the directory info,
    # but adjust values to the files contained
    my @dir = stat($src.$filename.".d/");
    #my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)
    #    = @orig;
    my @fstat = @dir;
    # the virtual file retains the directory permissions
    my $perms = ($fstat[2] & 07777);
    $fstat[2] = ( S_IFREG | $perms );
    # and has only one hardlink
    $fstat[3] = 1;
    
    # now we calculate values dependant from the file parts
    # e.g. the size
    $fstat[7] = 0;
    # and blocks
    $fstat[12] = 0;
    my @parts = file_parts($filename);
    for my $p (@parts) {
        my @pstat = stat($p);
        # the filesize is the sum of the size of all parts
        $fstat[7] += $pstat[7];
        # atime/mtime/ctime are set to the maximum encountered
        for my $i (8..10) {
            $fstat[$i] = ($pstat[$i] > $fstat[$i] ? $pstat[$i] : $fstat[$i]);
        }
        $fstat[12] += $pstat[12];
    }
    return @fstat;
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
