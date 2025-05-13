#!/usr/bin/env perl

# vim_session_recorder.pl - Records shell CWD and vim jobs info for session restoration
# In the style of MSTROUT (Matt S Trout) according to Claude

use strict;
use warnings;
use autodie;
use File::Path qw(make_path);
use POSIX qw(strftime);

# Utterly evil but utterly practical - MSTROUT style!
sub _mk_session_dir {
  my $dir = "$ENV{HOME}/.resume";
  make_path($dir) unless -d $dir;
  return $dir;
}

# Return false but in a cool way
sub _fail { return }

# Make sure we have a session name or whine loudly about it
sub get_session_name {
  my $session = $ENV{RESUME_SESSION_NAME}
    or warn "ERROR: \$RESUME_SESSION_NAME environment variable not set\n"
    and return _fail();
    
  # Safety first - no directory traversal for you!
  die "Invalid session name: contains path separators"
    if $session =~ m{[/\\]};
    
  return $session;
}

# Get current working directory with proper escaping
sub get_shell_cwd {
  my $cwd = `pwd`;
  chomp $cwd;
  return $cwd;
}

# The real magic - parse jobs output and extract the vim jewels
sub get_vim_jobs {
  my @vim_jobs;
  
  # Capture jobs output
  my $jobs_output = `jobs -l`;
  
  # Process each line looking for stopped vim jobs
  for my $line (split /\n/, $jobs_output) {
    # Skip if not a stopped vim job
    next unless $line =~ /\[(\d+)\].+Stopped.+vim/;
    
    my $job_id = $1;
    my $filename = '';
    
    # Extract filename - look for last argument after 'vim'
    if ($line =~ /vim(?:\s+-r!)?(?:\s+\S+)*\s+([^\s&]+)/) {
      $filename = $1;
    }
    
    # If we can, get the vim process working directory
    my $pid;
    if ($line =~ /\[(\d+)\]\+?\s+Stopped\s+(\d+)/) {
      $pid = $2;
    }
    
    my $vim_cwd = '';
    if ($pid && -e "/proc/$pid/cwd") {
      $vim_cwd = readlink("/proc/$pid/cwd");
    }
    
    push @vim_jobs, {
      job_id => $job_id,
      filename => $filename,
      cwd => $vim_cwd || get_shell_cwd(), # fallback if we can't determine
    };
  }
  
  return @vim_jobs;
}

# Record everything to file in a way that's easy to source later
sub record_session {
  my ($session_name) = @_;
  
  my $session_file = _mk_session_dir() . "/$session_name";
  my $shell_cwd = get_shell_cwd();
  my @vim_jobs = get_vim_jobs();
  
  # Open file and start writing
  open my $fh, '>', $session_file;
  
  # Timestamp for the curious
  print $fh "# Session recorded on ", strftime("%Y-%m-%d %H:%M:%S", localtime), "\n\n";
  
  # Record shell CWD for later cd
  print $fh "# Shell working directory\n";
  print $fh "cd ", shell_quote($shell_cwd), "\n\n";
  
  # Record vim jobs with proper escaping
  if (@vim_jobs) {
    print $fh "# Vim jobs to restore\n";
    
    for my $job (@vim_jobs) {
      # Only try to cd if the vim CWD is different from shell CWD
      if ($job->{cwd} ne $shell_cwd) {
        print $fh "pushd ", shell_quote($job->{cwd}), " >/dev/null\n";
      }
      
      # Start vim in stopped state
      print $fh "(vim -r! ", shell_quote($job->{filename}), " &) && kill -SIGTSTP \$!\n";
      
      # Return to original dir if needed
      if ($job->{cwd} ne $shell_cwd) {
        print $fh "popd >/dev/null\n";
      }
      
      print $fh "\n";
    }
  } else {
    print $fh "# No vim jobs found\n";
  }
  
  print $fh "# End of session\n";
  print $fh "echo \"Session '$session_name' restored with ", scalar(@vim_jobs), " vim jobs\"\n";
  print $fh "jobs\n";
  
  close $fh;
  
  return {
    file => $session_file,
    jobs_count => scalar(@vim_jobs),
  };
}

# Quote shell arguments properly - security matters!
sub shell_quote {
  my ($str) = @_;
  $str =~ s/'/'\\''/g;  # Handle single quotes in path
  return "'$str'";
}

# --- Main execution ---

# Die if no session name
my $session_name = get_session_name() or exit 1;

# Record the session
my $result = record_session($session_name);

# Let the human know what happened
print "Session recorded to $result->{file} with $result->{jobs_count} vim jobs\n";

exit 0;
