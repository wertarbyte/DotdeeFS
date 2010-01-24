#!/usr/bin/perl

package DotDeeFs;

use strict;
use Fuse;
use POSIX qw(ENOENT ENOSYS EEXIST EPERM O_RDONLY O_RDWR O_APPEND O_CREAT);
use Fcntl qw(:mode);

# data source directory
my $src = shift @ARGV;
# mountpoint
my $dst = shift @ARGV;

sub getattr {
    my ($file) = @_;
    print "getattr: $file\n";
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

sub read {
    my ($file, $requestedsize, $offset) = @_;
    return "";
}

Fuse::main(
    mountpoint  => $dst,
    getattr     => \&getattr,
    getdir      => \&getdir,
    read        => \&read,
    threaded    => 0,
    debug       => 1
);
