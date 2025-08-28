/**
 * DocumentEditor LiveView Hook
 * 
 * Handles real-time collaborative editing functionality:
 * - Text change detection and synchronization
 * - Cursor position tracking
 * - Visual cursor overlays for other users
 * - Typing indicators
 */

export const DocumentEditor = {
  mounted() {
    this.editor = this.el;
    this.cursors = new Map(); // Track other users' cursors
    this.lastContent = this.editor.value;
    this.typing = false;
    this.typingTimeout = null;
    
    this.setupEventListeners();
    this.initializeCursorTracking();
  },
  
  setupEventListeners() {
    // Content changes
    this.editor.addEventListener('input', (e) => {
      this.handleContentChange(e);
    });
    
    // Cursor/selection changes
    this.editor.addEventListener('selectionchange', () => {
      this.handleSelectionChange();
    });
    
    // Keyboard events for special keys
    this.editor.addEventListener('keydown', (e) => {
      // Ctrl+S to save
      if (e.ctrlKey && e.key === 's') {
        e.preventDefault();
        this.pushEvent('save_now', {});
      }
    });
    
    // Focus/blur events
    this.editor.addEventListener('focus', () => {
      this.updateTypingStatus(false); // Clear typing when focused
    });
    
    this.editor.addEventListener('blur', () => {
      this.updateTypingStatus(false); // Clear typing when blurred
    });
  },
  
  initializeCursorTracking() {
    // Create overlay container for cursors if it doesn't exist
    if (!document.getElementById('cursor-overlays')) {
      const overlay = document.createElement('div');
      overlay.id = 'cursor-overlays';
      overlay.className = 'absolute inset-0 pointer-events-none';
      this.editor.parentElement.appendChild(overlay);
    }
    this.cursorOverlay = document.getElementById('cursor-overlays');
  },
  
  handleContentChange(e) {
    const newContent = this.editor.value;
    
    // Only sync if content actually changed
    if (newContent !== this.lastContent) {
      this.lastContent = newContent;
      
      // Push content change to server
      this.pushEvent('content_changed', {
        content: newContent
      });
      
      // Update typing status
      this.updateTypingStatus(true);
    }
  },
  
  handleSelectionChange() {
    if (document.activeElement === this.editor) {
      const start = this.editor.selectionStart;
      const end = this.editor.selectionEnd;
      
      if (start === end) {
        // Just cursor movement
        this.pushEvent('cursor_moved', {
          position: start
        });
      } else {
        // Text selection
        this.pushEvent('selection_changed', {
          start: start,
          end: end
        });
      }
    }
  },
  
  updateTypingStatus(isTyping) {
    if (this.typing !== isTyping) {
      this.typing = isTyping;
      
      if (isTyping) {
        this.pushEvent('typing_started', {});
        
        // Clear typing status after 3 seconds of inactivity
        clearTimeout(this.typingTimeout);
        this.typingTimeout = setTimeout(() => {
          this.updateTypingStatus(false);
        }, 3000);
      } else {
        this.pushEvent('typing_stopped', {});
        clearTimeout(this.typingTimeout);
      }
    }
  },
  
  // Handle incoming events from server
  
  handleEvent(event, payload) {
    switch (event) {
      case 'content_updated':
        this.updateContent(payload.content);
        break;
      case 'cursor_updated':
        this.updateUserCursor(payload);
        break;
      case 'user_joined':
        this.addUser(payload);
        break;
      case 'user_left':
        this.removeUser(payload.session_id);
        break;
      case 'typing_updated':
        this.updateUserTyping(payload);
        break;
    }
  },
  
  updateContent(newContent) {
    // Save current cursor position
    const cursorPos = this.editor.selectionStart;
    const scrollTop = this.editor.scrollTop;
    
    // Update content if different
    if (this.editor.value !== newContent) {
      this.editor.value = newContent;
      this.lastContent = newContent;
      
      // Restore cursor position (basic approach)
      this.editor.setSelectionRange(cursorPos, cursorPos);
      this.editor.scrollTop = scrollTop;
    }
  },
  
  updateUserCursor(payload) {
    const { session_id, position, selection, user } = payload;
    
    // Don't show our own cursor
    if (session_id === this.sessionId) return;
    
    this.renderUserCursor(session_id, user, position, selection);
  },
  
  addUser(payload) {
    const { session_id, user } = payload;
    console.log(`User ${user.name} joined the document`);
    
    // Initialize cursor for new user
    this.cursors.set(session_id, {
      name: user.name,
      color: user.color,
      position: 0,
      selection: null
    });
  },
  
  removeUser(sessionId) {
    console.log(`User left the document`);
    
    // Remove cursor
    this.cursors.delete(sessionId);
    this.removeCursorElement(sessionId);
  },
  
  updateUserTyping(payload) {
    const { session_id, typing, user } = payload;
    
    // Update typing indicator in user cursor
    const cursor = this.cursors.get(session_id);
    if (cursor) {
      cursor.typing = typing;
      this.renderUserCursor(session_id, user, cursor.position, cursor.selection);
    }
  },
  
  renderUserCursor(sessionId, user, position, selection) {
    // Save cursor info
    this.cursors.set(sessionId, {
      name: user.name,
      color: user.color,
      position: position,
      selection: selection,
      typing: user.typing
    });
    
    // Remove existing cursor
    this.removeCursorElement(sessionId);
    
    // Calculate pixel position from text position
    const coords = this.getCoordinatesFromPosition(position);
    if (!coords) return;
    
    // Create cursor element
    const cursor = document.createElement('div');
    cursor.id = `cursor-${sessionId}`;
    cursor.className = 'absolute z-10';
    cursor.style.left = `${coords.left}px`;
    cursor.style.top = `${coords.top}px`;
    
    // Cursor line
    const line = document.createElement('div');
    line.className = 'w-0.5 h-5';
    line.style.backgroundColor = user.color;
    
    // User name label
    const label = document.createElement('div');
    label.className = 'absolute -top-6 left-0 px-2 py-1 text-xs text-white rounded shadow-lg whitespace-nowrap';
    label.style.backgroundColor = user.color;
    label.textContent = user.name + (user.typing ? ' ✍️' : '');
    
    cursor.appendChild(line);
    cursor.appendChild(label);
    
    // Handle selection highlighting
    if (selection && selection.start !== selection.end) {
      this.renderSelection(sessionId, user.color, selection.start, selection.end);
    }
    
    this.cursorOverlay.appendChild(cursor);
    
    // Auto-hide label after 3 seconds
    setTimeout(() => {
      if (label.parentElement) {
        label.style.opacity = '0';
        label.style.transition = 'opacity 0.3s';
      }
    }, 3000);
  },
  
  renderSelection(sessionId, color, start, end) {
    // Create selection highlights between start and end positions
    // This is a simplified version - a full implementation would handle multi-line selections
    const startCoords = this.getCoordinatesFromPosition(start);
    const endCoords = this.getCoordinatesFromPosition(end);
    
    if (startCoords && endCoords) {
      const selection = document.createElement('div');
      selection.id = `selection-${sessionId}`;
      selection.className = 'absolute';
      selection.style.left = `${startCoords.left}px`;
      selection.style.top = `${startCoords.top}px`;
      selection.style.width = `${endCoords.left - startCoords.left}px`;
      selection.style.height = '1.25rem'; // line height
      selection.style.backgroundColor = color;
      selection.style.opacity = '0.2';
      
      this.cursorOverlay.appendChild(selection);
    }
  },
  
  removeCursorElement(sessionId) {
    const cursor = document.getElementById(`cursor-${sessionId}`);
    const selection = document.getElementById(`selection-${sessionId}`);
    
    if (cursor) cursor.remove();
    if (selection) selection.remove();
  },
  
  getCoordinatesFromPosition(position) {
    // Create a temporary element to measure text position
    const tempDiv = document.createElement('div');
    const computedStyle = window.getComputedStyle(this.editor);
    
    // Copy relevant styles
    tempDiv.style.position = 'absolute';
    tempDiv.style.visibility = 'hidden';
    tempDiv.style.whiteSpace = 'pre-wrap';
    tempDiv.style.font = computedStyle.font;
    tempDiv.style.padding = computedStyle.padding;
    tempDiv.style.border = computedStyle.border;
    tempDiv.style.width = this.editor.offsetWidth + 'px';
    
    // Get text up to cursor position
    const textUpToCursor = this.editor.value.substring(0, position);
    tempDiv.textContent = textUpToCursor;
    
    // Add cursor marker
    const cursorSpan = document.createElement('span');
    cursorSpan.textContent = '|';
    tempDiv.appendChild(cursorSpan);
    
    document.body.appendChild(tempDiv);
    
    // Get cursor position relative to temp div
    const rect = cursorSpan.getBoundingClientRect();
    const editorRect = this.editor.getBoundingClientRect();
    
    const coords = {
      left: rect.left - editorRect.left + this.editor.scrollLeft,
      top: rect.top - editorRect.top + this.editor.scrollTop
    };
    
    document.body.removeChild(tempDiv);
    
    return coords;
  },
  
  destroyed() {
    // Clean up
    clearTimeout(this.typingTimeout);
    if (this.cursorOverlay) {
      this.cursorOverlay.innerHTML = '';
    }
  }
};

export const CopyToClipboard = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      const targetSelector = this.el.dataset.target;
      const targetElement = document.querySelector(targetSelector);
      
      if (targetElement) {
        targetElement.select();
        targetElement.setSelectionRange(0, 99999); // For mobile devices
        
        navigator.clipboard.writeText(targetElement.value).then(() => {
          this.pushEvent('copy_share_url', {});
        }).catch(err => {
          console.error('Failed to copy: ', err);
        });
      }
    });
  }
};
