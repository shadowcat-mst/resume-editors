# Add these functions to your .bashrc or .zshrc

# Shell code written by Claude with some guidance from mst

# Record current shell session including vim jobs
function record_vim_session() {
  local session_name="$1"
  
  if [ -z "$session_name" ]; then
    echo "Usage: record_vim_session SESSION_NAME"
    return 1
  fi
  
  # Set the session name and run the recorder
  export RESUME_SESSION_NAME="$session_name"
  /path/to/vim_session_recorder.pl
}

# PS1 hook to automatically record session periodically
function record_vim_session_hook() {
  # Only run if we have an active session name
  if [ -n "$RESUME_SESSION_NAME" ]; then
    # Run the recorder (silently)
    /path/to/vim_session_recorder.pl >/dev/null 2>&1
  fi
}

# Add to your PS1 if you want automatic recording
# PS1='...\$ $(record_vim_session_hook)'

# Start a new shell with restored session
function resume_vim_session() {
  local session_name="$1"
  
  if [ -z "$session_name" ]; then
    echo "Available sessions:"
    ls -1 ~/.resume/
    return 1
  fi
  
  local session_file="$HOME/.resume/$session_name"
  
  if [ ! -f "$session_file" ]; then
    echo "Session '$session_name' does not exist"
    return 1
  fi
  
  # Start a new shell with the session file as init file
  export RESUME_SESSION_NAME="$session_name"
  bash --init-file <(echo "source ~/.bashrc; source '$session_file'")
}

# Function to list available sessions
function list_vim_sessions() {
  if [ ! -d "$HOME/.resume" ]; then
    echo "No sessions found (directory does not exist)"
    return 1
  fi
  
  local count=$(ls -1 ~/.resume/ | wc -l)
  
  if [ $count -eq 0 ]; then
    echo "No sessions found"
    return 1
  fi
  
  echo "Available sessions ($count):"
  for session in $(ls -1 ~/.resume/); do
    local jobs_count=$(grep -c "vim -r!" "$HOME/.resume/$session")
    echo "  $session ($jobs_count vim jobs)"
  done
}

# Remove a session
function remove_vim_session() {
  local session_name="$1"
  
  if [ -z "$session_name" ]; then
    echo "Usage: remove_vim_session SESSION_NAME"
    return 1
  fi
  
  local session_file="$HOME/.resume/$session_name"
  
  if [ ! -f "$session_file" ]; then
    echo "Session '$session_name' does not exist"
    return 1
  fi
  
  rm "$session_file"
  echo "Session '$session_name' removed"
}
