#!/usr/bin/perl -w

# Persona (c)2003,2004 Stepan Roh <src@srnet.cz>
# personal pages generator

# $Id: persona.pl,v 1.35 2004/03/20 14:27:25 stepan Exp $

$prog_name = 'Persona';
$cvs_version = '$Revision: 1.35 $';
$prog_cvs_version = ($cvs_version =~ /:\s*(\S*)\s*\$/)[0];
$prog_version = '0.'.$prog_cvs_version;

use File::Copy;
use File::Spec;
use Digest::MD5 qw(md5_hex);

$test = 0;
if ($ARGV[0] eq '-test') {
  $test = 1;
  shift @ARGV;
}

$desc_file = shift @ARGV;
$dest_dir = shift @ARGV;
$log_file = shift @ARGV;
@languages = @ARGV;

%resource = ();
require $desc_file;
if (!defined $resource{'global'}{'banner'}) {
  $resource{'global'}{'banner'} = $prog_name.' '.$prog_version;
}

sub get_data_key($$$) {
  my ($res, $key, $lang) = @_;
  my $ret;
  if (exists ($resource{$res}{$key.'_'.$lang})) {
    $ret = $resource{$res}{$key.'_'.$lang};
  } else {
    $ret = $resource{$res}{$key};
  }
  if (!defined ($ret) && ($res ne 'global')) {
    if (exists ($resource{'global'}{$key.'_'.$lang})) {
      $ret = $resource{'global'}{$key.'_'.$lang};
    } else {
      $ret = $resource{'global'}{$key};
    }
  }
  if (ref ($ret) eq 'CODE') {
    $ret = &{$ret}($res, $key, $lang);
  }
  return $ret;
}

sub make_dirs ($$) {
  my ($path, $strip_file) = @_;
  $path = (File::Spec->splitpath ($path, !$strip_file))[1];
  my @dirs = File::Spec->splitdir ($path);
  my $fdir = '';
  foreach $dir (@dirs) {
    $fdir = File::Spec->catdir ($fdir, $dir);
    print STDOUT "Making directory $fdir\n";
    if (!$test) {
      mkdir $fdir;
    }
  }
}

sub md5sum_file ($;$$) {
  my ($fname, $binmode, $delre) = @_;
  open (FILE, '<'.$fname) || die "Unable to open file $fname : $!\n";
  binmode (FILE) if ($binmode);
  my $data = join ('', <FILE>);
  if ($delre) {
    $data =~ s/$delre//g;
  }
  my $md5 = md5_hex ($data);
  close (FILE);
  return $md5;
}

sub log_file_output ($$) {
  return if ($log_file eq '-');
  my ($file, $md5) = @_;
  open (LOG, '>>'.$log_file) || die "Unable to open $log_file : $!\n";
  print LOG $md5, ' ', $file, "\n";
  close (LOG);
}

sub copy_with_check ($$) {
  my ($src, $dest) = @_;
  my $srcmd5 = md5sum_file ($src, 1);
  log_file_output ($dest, $srcmd5);
  if (-f $dest) {
    my $destmd5 = md5sum_file ($dest, 1);
    if ($srcmd5 eq $destmd5) {
      print "MD5 digests are the same - no action taken\n";
      return;
    }
  }
  copy ($src, $dest) || die "Unable to copy file $src to $dest : $!\n";
  my @stat = stat ($src);
  utime ($stat[8], $stat[9], $dest) || die "Unable to set file times for $dest : $!\n";
}

sub copy_file ($$) {
  my ($srcfilename, $destfilename) = @_;
  $destfilename = File::Spec->rel2abs ($destfilename, $dest_dir);
  print STDOUT "Copying file $srcfilename to $destfilename\n";
  make_dirs ($destfilename, 1);
  if (!$test) {
    copy_with_check ($srcfilename, $destfilename);
  }
}

sub copy_dir_recursive ($$$);
sub copy_dir_recursive ($$$) {
  my ($src, $dest, $ignre) = @_;
  print STDOUT "Copying directory $src to $dest\n";
  opendir (DIR, $src) || die "Unable to open directory $src : $!\n";
  my @items = grep { ($_ ne '.') && ($_ ne '..') && (!$ignre || ($_ !~ /$ignre/)) } readdir (DIR);
  closedir (DIR);
  foreach $i (@items) {
    my $s = File::Spec->catfile ($src, $i);
    my $d = File::Spec->catfile ($dest, $i);
    if (-d $s) {
      print STDOUT "Making directory $d\n";
      if (!$test) {
        mkdir ($d);
      }
      copy_dir_recursive ($s, $d, $ignre);
    } elsif (-f $s) {
      print STDOUT "Copying file $s to $d\n";
      if (!$test) {
        copy_with_check ($s, $d);
      }
    } else {
      warn "$s is neither file nor directory";
    }
  }
}

sub copy_dir ($$$) {
  my ($srcdirname, $destdirname, $ignre) = @_;
  $destdirname = File::Spec->rel2abs ($destdirname, $dest_dir);
  make_dirs ($destdirname, 0);
  copy_dir_recursive ($srcdirname, $destdirname, $ignre);
}

sub read_file ($) {
  my ($fname) = @_;
  print STDOUT "Loading file $fname\n";
  open (F, $fname) || die "Unable to open $fname : $!\n";
  my $read = join ('', <F>);
  close (F);
  return $read;
}

sub write_file ($$;$) {
  my ($text, $fname, $delre) = @_;
  $fname = File::Spec->rel2abs ($fname, $dest_dir);
  print STDOUT "Writing file $fname\n";
  make_dirs ($fname, 1);
  if (!$test) {
    my $copy_text = $text;
    if ($delre) {
      $copy_text =~ s/$delre//g;
    }
    my $srcmd5 = md5_hex ($copy_text);
    log_file_output ($fname, $srcmd5);
    if (-f $fname) {
      my $destmd5 = md5sum_file ($fname, 0, $delre);
      if ($srcmd5 eq $destmd5) {
        print "MD5 digests are the same - no action taken\n";
        return;
      }
    }
    open (F, ">$fname") || die "Unable to open $fname : $!\n";
    print F $text;
    close (F);
  }
}

sub get_source ($$$) {
  my ($res, $lang, $can_die) = @_;
  my %source = %{get_data_key($res, 'source', $lang)};
  if (!%source && $can_die) {
    die "Resource $res has no source";
  }
  return %source;
}

sub is_absolute_location ($) {
  my ($loc) = @_;
  return ($loc =~ m,^(/|http:|file:|news:|mailto:|ftp:),);
}

sub rel_location ($$$) {
  my ($loc, $res, $lang) = @_;
  return $loc if (is_absolute_location ($loc));
  my %source = get_source ($res, $lang, 1);
  my $resloc = $source{'dest'};
  my @from = split ('/', $resloc);
  my @to = split ('/', $loc);
  return $from[$#from] if ($resloc eq $loc);
  my $i;
  for ($i = 0; $i < @from; $i++) {
    my $from = $from[$i];
    my $to = $to[$i];
    last if (!defined $to);
    last if ($from ne $to);
  }
  my $ups = @from - $i - 1;
  if (!defined $to[$i]) {
    return ($ups) ? ('../' x $ups) : './';
  }
  return ('../' x $ups) . join ('/', @to[$i..$#to]) . (($loc =~ m,/$,) ? '/' : '');
}

sub replace_entities ($) {
  my ($text) = @_;
  $text =~ s/&lt;/</g;
  $text =~ s/&gt;/>/g;
  $text =~ s/&amp;/&/g;
  return $text;
}

sub execute ($$) {
  my ($fname, $code) = @_;
  my $ret = eval $code;
  if (!defined $ret) {
    die "Embedded code execution failure:\n  file: $fname\n  code: $code\n  error:\n$@\n";
  }
  return $ret;
}

sub process_template($$$;$) {
  local ($_fname, $_inc_res, $_lang, $_res) = @_;
  
  ($_res = $_inc_res) if (!defined $_res);
  
  sub location (;$$) {
    my ($res, $lang) = @_;
    ($res = $_res) if (!defined $res);
    ($lang = $_lang) if (!defined $lang);
    my %source = get_source ($res, $lang, 1);
    my $loc = $source{'dest'};
    return rel_location ($loc, $_res, $_lang);
  }
  sub abs_location ($;$$) {
    my ($prefix, $res, $lang) = @_;
    ($res = $_res) if (!defined $res);
    ($lang = $_lang) if (!defined $lang);
    my %source = get_source ($res, $lang, 1);
    my $loc = $source{'dest'};
    return $prefix . $loc;
  }
  sub file (;$$) {
    my ($res, $lang) = @_;
    ($res = $_res) if (!defined $res);
    ($lang = $_lang) if (!defined $lang);
    my %source = get_source ($res, $lang, 1);
    return $source{'file'};
  }
  sub language () {
    return $_lang;
  }
  sub resource () {
    return $_res;
  }
  sub data($;$$) {
    my ($name, $res, $lang) = @_;
    ($res = $_res) if (!defined $res);
    ($lang = $_lang) if (!defined $lang);
    my $val = get_data_key ($res, $name, $lang);
    if (!defined $val) {
      die "Unknown key $name in resource $res for language $lang";
    }
    return $val;
  }
  sub matching($$) {
    my ($name, $val) = @_;
    my @ret = ();
    foreach $res (keys %resource) {
      my $hidden = get_data_key ($res, 'hidden', $_lang);
      next if ($hidden);
      my $v = get_data_key ($res, $name, $_lang);
      if (defined ($v) && ($v eq $val)) {
        push (@ret, $res);
      }
    }
    my @order = @{get_data_key ($res, 'resource_order', $_lang)};
    if (!@order) {
      @order = ();
    }
    local %order = ();
    for (my $i = 0; $i < @order; $i++) {
      my $o = $order[$i];
      $order{$o} = $i;
    }
    sub res_order_pos ($) {
      my ($res) = @_;
      if (exists $order{$res}) {
        return $order{$res};
      }
      return scalar (keys %order);
    }
    @ret = sort { res_order_pos($a) <=> res_order_pos($b) } @ret;
    return @ret;
  }
  sub respath(;$) {
    my ($res) = @_;
    ($res = $_res) if (!defined $res);
    my @ret = ($res);
    while (defined ($res = $resource{$res}{'parent'})) {
      unshift (@ret, $res);
    };
    return @ret;
  }
  sub reslang(;$) {
    my ($res) = @_;
    ($res = $_res) if (!defined $res);
    my @ret = ();
    if (exists $resource{$res}{'languages'}) {
      @ret = @{$resource{$res}{'languages'}};
    }
    return @ret;
  }
  sub include($) {
    my ($res) = @_;
    return process_resource_for_include ($res, $_lang, $_inc_res);
  }
  
  my $template = read_file ($_fname);
  $template =~ s;\Q<? \E(.*?)(\Q/?>\E|\Q?>\E.*?\Q<?/?>\E);execute ($_fname, replace_entities($1));seg;
  return $template;
}

sub process_resource_for_include($$$) {
  my ($res, $lang, $top_res) = @_;
  my $type = $resource{$res}{'type'};
  print STDOUT "Include resource: $res\n";
  my %source = get_source ($res, $lang, 1);
  die "Can not include resource $res without source file" if (!exists $source{'file'});
  if ($type eq 'file') {
    return read_file ($source{'file'});
  } elsif ($type eq 'template') {
    return process_template ($source{'file'}, $res, $lang, $top_res);
  } else {
    die "Can not include resource $res with type $type";
  }
}

sub has_language($$) {
  my ($res, $lang) = @_;
  my $langs_ref = get_data_key ($res, 'languages', $lang);
  return 1 if (!defined $langs_ref);
  my @langs = @{$langs_ref};
  foreach $l (@langs) {
    return 1 if ($l eq $lang);
  }
  return 0;
}

sub process_resource($$) {
  my ($res, $lang) = @_;
  my $ign_lang = !defined get_data_key ($res, 'languages', $lang);
  if ($ign_lang) {
    return if ($resource{$res}{'processed'});
  } else {
    return if ($resource{$res}{'processed_'.$lang});
  }
  my $type = $resource{$res}{'type'};
  return if ($type eq 'global');
  print STDOUT "Resource: $res\n";
  if ($ign_lang) {
    $resource{$res}{'processed'} = 1;
  } else {
    $resource{$res}{'processed_'.$lang} = 1;
  }
  return if ($type =~ /^x/);
  my %source = get_source ($res, $lang, 0);
  return if (!%source);
  return if (!exists $source{'dest'});
  return if (!exists $source{'file'});
  return if (!has_language ($res, $lang));
  if ($type eq 'file') {
    copy_file ($source{'file'}, $source{'dest'});
  } elsif ($type eq 'dir') {
    copy_dir ($source{'file'}, $source{'dest'}, $source{'ignore'});
  } elsif ($type eq 'template') {
    my $processed = process_template($source{'file'}, $res, $lang);
    my $delre = get_data_key ($res, 'comparator_regexp', $lang);
    write_file ($processed, $source{'dest'}, $delre);
  } else {
    die "Unknown type: $type";
  }
}

foreach $lang (@languages) {
  print STDOUT "Language: $lang\n";
  foreach $res (keys %resource) {
    process_resource($res, $lang);
  }
}

1;
