#!/usr/bin/env perl

# vim_session_recorder.pl - Records shell CWD and vim jobs info for session restoration
# In the style of MSTROUT (Matt S Trout) according to Claude

use strict;
use warnings;
use autodie;
use File::Path qw(make_path);
use POSIX qw(strftime);
use Cwd qw(cwd);

# Utterly evil but utterly practical - MSTROUT style!
sub _mk_session_dir {
  my $dir = "$ENV{HOME}/.resume";
  make_path($dir) unless -d $dir;
  return $dir;
}

# Make sure we have a session name or whine loudly about it
sub get_session_name {
  my $session = $ENV{RESUME_SESSION_NAME}
    or die "ERROR: \$RESUME_SESSION_NAME environment variable not set\n";
    
  # Safety first - no directory traversal for you!
  die "Invalid session name: contains path separators"
    if $session =~ m{[/\\]};
    
  return $session;
}

# The real magic - parse jobs output and extract the vim jewels
sub get_vim_jobs {
  my ($jobs_output) = @_;
  my @vim_jobs;
  
  # Process each line looking for stopped vim jobs
  for my $line (split /\n/, $jobs_output) {
    # Skip if not a stopped vim job
    next unless $line =~ /\[(\d+)\].+Stopped.+vim/;
    my $job_id = $1;
    
    # Extract filename - look for last argument after 'vim'
    next unless my ($filename) = $line =~ /vim(?:\s+-r!)?(?:\s+\S+)*\s+([^\s&]+)/;
    
    # Get the pid if available
    my ($pid) = $line =~ /\[\d+\]\+?\s+Stopped\s+(\d+)/;
    
    # Get vim working directory (from /proc if possible, otherwise current dir)
    my $vim_cwd = ($pid && -e "/proc/$pid/cwd") ? readlink("/proc/$pid/cwd") : cwd();
    
    push @vim_jobs, {
      job_id => $job_id,
      filename => $filename,
      cwd => $vim_cwd,
    };
  }
  
  return @vim_jobs;
}

# Record everything to file in a way that's easy to source later
sub record_session {
  my ($session_name, $jobs_output) = @_;
  
  my $session_file = _mk_session_dir() . "/$session_name";
  my $shell_cwd = cwd();
  my @vim_jobs = get_vim_jobs($jobs_output);
  
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
      # Start vim in stopped state - using cd inside the subshell if needed
      if ($job->{cwd} ne $shell_cwd) {
        print $fh "(cd ", shell_quote($job->{cwd}), " && vim -r! ", shell_quote($job->{filename}), " &) && kill -SIGTSTP \$!\n";
      } else {
        print $fh "(vim -r! ", shell_quote($job->{filename}), " &) && kill -SIGTSTP \$!\n";
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
  $str =~ s/'/'"'"'/g;  # Handle single quotes in path with '"'"'
  return "'$str'";
}

# --- Main execution ---

# Die if no session name
my $session_name = get_session_name();

# Get jobs output from stdin
my $jobs_output = do { local $/; <STDIN> };

# Record the session
my $result = record_session($session_name, $jobs_output);

# Let the human know what happened
print "Session recorded to $result->{file} with $result->{jobs_count} vim jobs\n";

exit 0;
