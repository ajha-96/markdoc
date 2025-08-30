/**
 * CollaborativeEditor - Real-time collaborative text editing with Phoenix Channels
 * 
 * Features:
 * - Real-time text synchronization using operational transforms
 * - Visual cursors and selections for all users
 * - Conflict-free concurrent editing
 * - Automatic reconnection and sync
 */

import {Socket} from "phoenix"
import {MarkdownPreview} from './markdown_preview.js'

export class CollaborativeEditor {
  constructor(element, documentId, userId, userName) {
    this.editor = element;
    this.documentId = documentId;
    this.userId = userId;
    this.userName = userName;
    
    // State management
    this.content = this.editor.value;
    this.version = 0;
    this.users = new Map();
    this.pendingOperations = [];
    this.acknowledged = 0;
    this.isTyping = false;
    this.typingTimeout = null;
    this.cursorUpdateTimeout = null;
    
    // UI elements
    this.cursors = new Map();
    this.setupCursorOverlay();
    
    // Initialize markdown preview for real-time rendering
    this.initializeMarkdownPreview();
    
    // Operational transform state
    this.localOperations = [];
    this.serverOperations = [];
    
    this.setupSocket();
    this.setupEventListeners();
    this.startCollaboration();
  }
  
  setupSocket() {
    // Create Phoenix socket connection with error handling
    this.socket = new Socket("/socket", {
      logger: (kind, msg, data) => {
        if (kind === "error") {
          console.error("🔌 Socket error:", msg, data);
        }
      },
      reconnectAfterMs: (tries) => {
        return [1000, 2000, 5000, 10000][tries - 1] || 10000;
      }
    });
    
    this.socket.onError(() => {
      console.error("🔌 Socket connection error");
    });
    
    this.socket.onClose(() => {
      console.warn("🔌 Socket connection closed");
    });
    
    this.socket.connect();
    
    // Join document channel with user info
    this.channel = this.socket.channel(`document:${this.documentId}`, {
      user_name: this.userName,
      session_id: this.userId
    });
    
    // Handle channel events
    this.channel.on("text_operation", (payload) => {
      console.log("📡 Received text_operation from channel:", payload);
      this.handleRemoteOperation(payload);
    });
    
    this.channel.on("cursor_update", (payload) => {
      this.handleCursorUpdate(payload);
    });
    
    this.channel.on("typing_status", (payload) => {
      this.handleTypingUpdate(payload);
    });
    
    this.channel.on("user_joined", (payload) => {
      this.handleUserJoined(payload);
    });
    
    this.channel.on("user_left", (payload) => {
      this.handleUserLeft(payload);
    });
  }
  
  startCollaboration() {
    console.log("🔌 Attempting to join channel for user:", this.userName, "- UserId:", this.userId);
    this.channel.join()
      .receive("ok", (response) => {
        console.log("🎉 Joined document channel successfully for user:", this.userName);
        console.log("📊 Initial channel state:", response);
        this.handleInitialState(response);
      })
      .receive("error", (resp) => {
        console.error("❌ Unable to join document channel", resp);
        // Attempt to reconnect after a delay
        setTimeout(() => {
          console.log("🔄 Attempting to rejoin channel...");
          this.startCollaboration();
        }, 2000);
      })
      .receive("timeout", () => {
        console.error("⏰ Channel join timed out");
        // Attempt to reconnect after a delay
        setTimeout(() => {
          console.log("🔄 Retrying channel join after timeout...");
          this.startCollaboration();
        }, 3000);
      });
  }
  
  handleInitialState(state) {
    console.log("📊 Initializing with state:", state);
    
    // Set initial content and version
    this.content = state.content || '';
    this.version = state.version || 0;
    
    // Force update editor content to match server state
    const currentContent = this.editor.value || '';
    if (currentContent !== this.content) {
      console.log(`🔧 Initial sync: updating editor from "${currentContent}" to "${this.content}"`);
      const cursorPos = this.editor.selectionStart;
      this.editor.value = this.content;
      
      // Set cursor to a safe position
      const safeCursorPos = Math.min(Math.max(0, cursorPos), this.content.length);
      this.editor.setSelectionRange(safeCursorPos, safeCursorPos);
    }
    
    // Clear any pending operations since we're syncing to server state
    this.localOperations = [];
    this.acknowledged = 0;
    
    // Initialize users
    if (state.users) {
      Object.values(state.users).forEach(user => {
        if (user.session_id !== this.userId) {
          this.users.set(user.session_id, user);
        }
      });
    }
    
    // Initialize cursor positions
    if (state.cursor_positions) {
      state.cursor_positions.forEach(cursor => {
        if (cursor.session_id !== this.userId) {
          this.updateUserCursor(cursor);
        }
      });
    }
    
    console.log("✅ Initial state sync completed");
    
    // Content sync now handled exclusively by Phoenix Channels
  }
  
  // Removed periodic sync - Phoenix Channels provide reliable real-time updates
  
  setupEventListeners() {
    // Content changes
    this.editor.addEventListener('input', (e) => {
      this.handleLocalInput(e);
    });
    
    // Selection changes - use 'select' event and click for better compatibility
    this.editor.addEventListener('select', () => {
      this.handleSelectionChange();
    });
    
    // Mouse/keyboard events that can change cursor position
    this.editor.addEventListener('click', () => {
      this.handleSelectionChange();
    });
    
    this.editor.addEventListener('keyup', (e) => {
      // Handle arrow keys, home, end, etc.
      if (e.key.startsWith('Arrow') || ['Home', 'End', 'PageUp', 'PageDown'].includes(e.key)) {
        this.handleSelectionChange();
      }
    });
    
    // Keyboard events
    this.editor.addEventListener('keydown', (e) => {
      this.handleKeyDown(e);
    });
    
    // Focus/blur for typing indicators
    this.editor.addEventListener('focus', () => {
      // Don't immediately show typing on focus
    });
    
    this.editor.addEventListener('blur', () => {
      this.setTypingStatus(false);
    });
  }
  
  handleLocalInput(e) {
    try {
      const newContent = this.editor.value || '';
      const operation = this.detectOperation(this.content || '', newContent);
      
      if (operation) {
        // Apply operation locally
        this.content = newContent;
        
        // Update preview in real-time
        this.updatePreview();
        
        // Send to server
        this.sendOperation(operation);
        
        // Update typing status
        this.setTypingStatus(true);
        this.scheduleTypingStop();
      }
    } catch (error) {
      console.error("❌ Error handling local input:", error);
      // Request sync to recover from error
      this.requestSync();
    }
  }
  
  detectOperation(oldContent, newContent) {
    // Simple diff algorithm to detect what changed
    const oldLen = oldContent.length;
    const newLen = newContent.length;
    
    if (oldLen === newLen) {
      // Content length same, might be a replacement (ignore for simplicity)
      return null;
    }
    
    // Find common prefix
    let prefixLen = 0;
    while (prefixLen < Math.min(oldLen, newLen) && 
           oldContent[prefixLen] === newContent[prefixLen]) {
      prefixLen++;
    }
    
    // Find common suffix
    let suffixLen = 0;
    while (suffixLen < Math.min(oldLen - prefixLen, newLen - prefixLen) &&
           oldContent[oldLen - 1 - suffixLen] === newContent[newLen - 1 - suffixLen]) {
      suffixLen++;
    }
    
    const deletedLen = oldLen - prefixLen - suffixLen;
    const insertedText = newContent.slice(prefixLen, newLen - suffixLen);
    
    if (deletedLen > 0 && insertedText.length > 0) {
      // Replace operation - send as atomic replace to avoid content flickering
      console.log(`🔄 Replace operation: replacing ${deletedLen} chars at ${prefixLen} with "${insertedText}"`);
      return {
        type: 'replace',
        position: prefixLen,
        content: insertedText,
        length: insertedText.length,
        deletedLength: deletedLen,
        timestamp: Date.now()
      };
    } else if (deletedLen > 0) {
      // Delete operation
      console.log(`🗑️ Delete operation: removing ${deletedLen} chars at position ${prefixLen}`);
      return {
        type: 'delete',
        position: prefixLen,
        content: '',
        length: deletedLen,
        timestamp: Date.now()
      };
    } else if (insertedText.length > 0) {
      // Insert operation
      console.log(`✏️ Insert operation: adding "${insertedText}" at position ${prefixLen}`);
      return {
        type: 'insert',
        position: prefixLen,
        content: insertedText,
        length: insertedText.length,
        timestamp: Date.now()
      };
    }
    
    return null;
  }
  
  sendOperation(operation) {
    console.log("🚀 Sending operation to server:", operation);
    this.channel.push("text_operation", {
      operation: operation
    }).receive("ok", (response) => {
      console.log("✅ Operation acknowledged by server");
      this.version = response.version;
    }).receive("error", (response) => {
      console.error("❌ Operation failed:", response);
      // Request sync to recover from error
      this.requestSync();
    });
  }


  
  handleRemoteOperation(payload) {
    const { operation, session_id, version } = payload;
    
    console.log("📡 Received remote operation:", {
      operation: operation,
      session_id: session_id,
      version: version,
      myUserId: this.userId
    });
    
    if (session_id === this.userId) {
      console.log("⏸️ Ignoring own operation echo");
      return; // Ignore our own operations echoed back
    }
    
    // Apply remote operation directly (server handles transformation)
    const oldContent = this.content;
    this.content = this.applyOperation(this.content, operation);
    
    // Update preview after remote changes
    this.updatePreview();
    
    console.log(`📝 Applied remote operation: "${oldContent}" -> "${this.content}"`);
    
    // Update editor content immediately - no LiveView conflicts anymore
    this.updateEditorContent(operation);
    
    // Update version to match server
    this.version = version;
    
    // Adjust cursor positions for all users
    this.adjustAllCursors(operation);
  }
  
  applyOperation(content, operation) {
    switch (operation.type) {
      case 'insert':
        return content.slice(0, operation.position) + 
               operation.content + 
               content.slice(operation.position);
      
      case 'delete':
        console.log(`🗑️ Applying delete operation: position=${operation.position}, length=${operation.length}, contentLen=${content.length}`);
        const result = content.slice(0, operation.position) + 
                      content.slice(operation.position + operation.length);
        console.log(`🗑️ Delete result: "${content}" -> "${result}"`);
        return result;
      
      case 'replace':
        console.log(`🔄 Applying replace operation: position=${operation.position}, deletedLength=${operation.deletedLength}, newContent="${operation.content}"`);
        const replaceResult = content.slice(0, operation.position) + 
                             operation.content + 
                             content.slice(operation.position + operation.deletedLength);
        console.log(`🔄 Replace result: "${content}" -> "${replaceResult}"`);
        return replaceResult;
      
      default:
        return content;
    }
  }
  
  updateEditorContent(operation) {
    const currentEditorContent = this.editor.value;
    const expectedContent = this.content;
    
    // Check if update is needed
    if (currentEditorContent === expectedContent) {
      console.log("✅ Editor content already synchronized");
      return;
    }
    
    console.log(`📝 Syncing editor content`);
    
    // Preserve cursor position and focus
    const hadFocus = document.activeElement === this.editor;
    const cursorStart = this.editor.selectionStart;
    const cursorEnd = this.editor.selectionEnd;
    
    // Update content
    this.editor.value = expectedContent;
    
    // Restore cursor position if user had focus
    if (hadFocus) {
      let adjustedStart = this.adjustCursorForOperation(cursorStart, operation);
      let adjustedEnd = this.adjustCursorForOperation(cursorEnd, operation);
      
      // Ensure positions are within bounds
      const safeStart = Math.min(Math.max(0, adjustedStart), expectedContent.length);
      const safeEnd = Math.min(Math.max(0, adjustedEnd), expectedContent.length);
      
      this.editor.setSelectionRange(safeStart, safeEnd);
      this.editor.focus();
    }
  }
  
  // Removed forceEditorSync - simplified to single updateEditorContent method
  
  transformOperation(op1, op2) {
    // Enhanced operational transform with better edge case handling
    
    if (!op1 || !op2) return op1;
    
    // Ensure positions are valid
    const normalizeOp = (op) => ({
      ...op,
      position: Math.max(0, op.position || 0),
      length: Math.max(0, op.length || 0),
      deletedLength: Math.max(0, op.deletedLength || 0),
      content: op.content || ''
    });
    
    const normalizedOp1 = normalizeOp(op1);
    const normalizedOp2 = normalizeOp(op2);
    
    // Handle replace operations by treating them as delete + insert
    if (normalizedOp1.type === 'replace') {
      // For replace, we need to handle position adjustment properly
      if (normalizedOp2.type === 'insert') {
        if (normalizedOp2.position <= normalizedOp1.position) {
          // Insert happens before replace - shift replace position
          return { ...normalizedOp1, position: normalizedOp1.position + normalizedOp2.content.length };
        } else if (normalizedOp2.position <= normalizedOp1.position + normalizedOp1.deletedLength) {
          // Insert happens within replace region - keep replace position same
          return normalizedOp1;
        } else {
          // Insert happens after replace region - no change needed
          return normalizedOp1;
        }
      } else if (normalizedOp2.type === 'delete') {
        const deleteEnd = normalizedOp2.position + normalizedOp2.length;
        if (deleteEnd <= normalizedOp1.position) {
          // Delete happens before replace - shift replace position back
          return { ...normalizedOp1, position: normalizedOp1.position - normalizedOp2.length };
        } else {
          // More complex case - for now keep original position
          return normalizedOp1;
        }
      }
      return normalizedOp1;
    }
    
    if (normalizedOp2.type === 'replace') {
      // Transform against replace operation
      const replaceEnd = normalizedOp2.position + normalizedOp2.deletedLength;
      const lengthDiff = normalizedOp2.content.length - normalizedOp2.deletedLength;
      
      if (normalizedOp1.type === 'insert') {
        if (normalizedOp1.position <= normalizedOp2.position) {
          return normalizedOp1;  // Insert before replace
        } else if (normalizedOp1.position <= replaceEnd) {
          return { ...normalizedOp1, position: normalizedOp2.position + normalizedOp2.content.length };  // Insert within replace
        } else {
          return { ...normalizedOp1, position: normalizedOp1.position + lengthDiff };  // Insert after replace
        }
      } else if (normalizedOp1.type === 'delete') {
        if (normalizedOp1.position + normalizedOp1.length <= normalizedOp2.position) {
          return normalizedOp1;  // Delete before replace
        } else if (normalizedOp1.position >= replaceEnd) {
          return { ...normalizedOp1, position: normalizedOp1.position + lengthDiff };  // Delete after replace
        } else {
          // Delete overlaps with replace - complex case, keep original for now
          return normalizedOp1;
        }
      }
      return normalizedOp1;
    }
    
    if (normalizedOp1.type === 'insert' && normalizedOp2.type === 'insert') {
      // Insert vs Insert
      if (normalizedOp1.position <= normalizedOp2.position) {
        return { ...normalizedOp1, position: normalizedOp1.position + normalizedOp2.content.length };
      }
      return normalizedOp1;
      
    } else if (normalizedOp1.type === 'insert' && normalizedOp2.type === 'delete') {
      // Insert vs Delete
      const deleteEnd = normalizedOp2.position + normalizedOp2.length;
      
      if (normalizedOp1.position <= normalizedOp2.position) {
        // Insert before delete region - no change needed
        return normalizedOp1;
      } else if (normalizedOp1.position >= deleteEnd) {
        // Insert after delete region - shift position back
        return { ...normalizedOp1, position: normalizedOp1.position - normalizedOp2.length };
      } else {
        // Insert within delete region - move to start of delete
        return { ...normalizedOp1, position: normalizedOp2.position };
      }
      
    } else if (normalizedOp1.type === 'delete' && normalizedOp2.type === 'insert') {
      // Delete vs Insert
      if (normalizedOp1.position <= normalizedOp2.position) {
        // Delete starts before or at insert - no change to delete position
        return normalizedOp1;
      } else {
        // Delete starts after insert - shift position forward
        return { ...normalizedOp1, position: normalizedOp1.position + normalizedOp2.content.length };
      }
      
    } else if (normalizedOp1.type === 'delete' && normalizedOp2.type === 'delete') {
      // Delete vs Delete
      const op1End = normalizedOp1.position + normalizedOp1.length;
      const op2End = normalizedOp2.position + normalizedOp2.length;
      
      if (op1End <= normalizedOp2.position) {
        // op1 completely before op2 - no change needed
        return normalizedOp1;
      } else if (normalizedOp1.position >= op2End) {
        // op1 completely after op2 - shift position back
        return { ...normalizedOp1, position: normalizedOp1.position - normalizedOp2.length };
      } else {
        // Overlapping deletes - complex case
        const overlapStart = Math.max(normalizedOp1.position, normalizedOp2.position);
        const overlapEnd = Math.min(op1End, op2End);
        const overlapLength = Math.max(0, overlapEnd - overlapStart);
        
        // Adjust the delete operation
        const newPosition = Math.min(normalizedOp1.position, normalizedOp2.position);
        const newLength = Math.max(0, normalizedOp1.length - overlapLength);
        
        return { ...normalizedOp1, position: newPosition, length: newLength };
      }
    }
    
    return normalizedOp1;
  }
  
  adjustCursorForOperation(cursorPos, operation) {
    if (!operation || cursorPos < 0) return cursorPos;
    
    switch (operation.type) {
      case 'insert':
        // If cursor is after insertion point, move it right by inserted length
        return cursorPos >= operation.position ? 
               cursorPos + operation.content.length : cursorPos;
      
      case 'delete':
        const deleteEnd = operation.position + operation.length;
        if (cursorPos <= operation.position) {
          // Cursor before deletion - no change
          return cursorPos;
        } else if (cursorPos <= deleteEnd) {
          // Cursor within deleted region - move to deletion start
          return operation.position;
        } else {
          // Cursor after deletion - move left by deleted length
          return cursorPos - operation.length;
        }
      
      case 'replace':
        const replaceEnd = operation.position + operation.deletedLength;
        if (cursorPos <= operation.position) {
          // Cursor before replacement - no change
          return cursorPos;
        } else if (cursorPos <= replaceEnd) {
          // Cursor within replaced region - move to end of replacement
          return operation.position + operation.content.length;
        } else {
          // Cursor after replacement - adjust by length difference
          const lengthDiff = operation.content.length - operation.deletedLength;
          return cursorPos + lengthDiff;
        }
      
      default:
        return cursorPos;
    }
  }
  
    
  // Selection and cursor handling
  handleSelectionChange() {
    // Debounce cursor updates to avoid too many messages
    clearTimeout(this.cursorUpdateTimeout);
    this.cursorUpdateTimeout = setTimeout(() => {
      const start = this.editor.selectionStart;
      const end = this.editor.selectionEnd;
      
      // Send cursor position to server
      if (this.channel) {
        this.channel.push("cursor_update", {
          position: start,
          selection: start !== end ? { start, end } : null
        });
      }
    }, 100); // 100ms debounce
  }

  handleKeyDown(e) {
    // Don't interfere with normal key handling, just track typing
    if (!this.isTyping && e.key.length === 1) {
      this.setTypingStatus(true);
    }
  }

  // Cursor visualization methods
  
  setupCursorOverlay() {
    if (!document.getElementById('cursor-overlay')) {
      const overlay = document.createElement('div');
      overlay.id = 'cursor-overlay';
      overlay.className = 'absolute inset-0 pointer-events-none z-10';
      this.editor.parentElement.style.position = 'relative';
      this.editor.parentElement.appendChild(overlay);
    }
    this.cursorOverlay = document.getElementById('cursor-overlay');
  }
  
  updateUserCursor(cursor) {
    this.removeCursor(cursor.session_id);
    
    const coords = this.getCoordinatesFromPosition(cursor.position);
    if (!coords) return;
    
    // Create cursor container with smooth animations
    const cursorElement = document.createElement('div');
    cursorElement.id = `cursor-${cursor.session_id}`;
    cursorElement.className = 'absolute collaborative-cursor-container';
    cursorElement.style.left = `${coords.left}px`;
    cursorElement.style.top = `${coords.top}px`;
    cursorElement.style.zIndex = '30';
    cursorElement.style.pointerEvents = 'none';
    
    // Animated cursor line with pulse effect
    const line = document.createElement('div');
    line.className = `w-0.5 h-6 rounded-full shadow-sm collaborative-cursor ${cursor.typing ? 'typing' : ''}`;
    line.style.backgroundColor = cursor.color;
    line.style.color = cursor.color;
    line.style.boxShadow = `0 0 4px ${cursor.color}40`;
    
    // Enhanced user label with better styling
    const label = document.createElement('div');
    label.className = `absolute -top-8 left-0 px-3 py-1 text-xs font-medium text-white rounded-lg shadow-lg whitespace-nowrap border-l-2 collaborative-cursor-label ${cursor.typing ? 'typing' : ''}`;
    label.style.backgroundColor = cursor.color;
    label.style.borderLeftColor = this.lightenColor(cursor.color, 20);
    label.style.fontSize = '11px';
    label.style.fontWeight = '500';
    label.style.letterSpacing = '0.02em';
    
    // Enhanced label content with typing indicator
    const nameSpan = document.createElement('span');
    nameSpan.textContent = cursor.name;
    label.appendChild(nameSpan);
    
    if (cursor.typing) {
      const typingIcon = document.createElement('span');
      typingIcon.className = 'ml-2 animate-bounce';
      typingIcon.textContent = '✍️';
      typingIcon.style.display = 'inline-block';
      typingIcon.style.fontSize = '10px';
      label.appendChild(typingIcon);
      
      // Add subtle typing glow
      label.style.boxShadow = `0 0 8px ${cursor.color}60, 0 4px 6px rgba(0, 0, 0, 0.1)`;
    } else {
      label.style.boxShadow = '0 2px 4px rgba(0, 0, 0, 0.1)';
    }
    
    // Hover effect for labels
    label.addEventListener('mouseenter', () => {
      label.style.transform = 'scale(1.05) translateY(-1px)';
      label.style.transition = 'transform 0.2s ease';
    });
    
    label.addEventListener('mouseleave', () => {
      label.style.transform = 'scale(1) translateY(0)';
    });
    
    cursorElement.appendChild(line);
    cursorElement.appendChild(label);
    
    // Enhanced selection highlighting
    if (cursor.selection) {
      this.renderSelection(cursor.session_id, cursor.color, cursor.selection);
    }
    
    this.cursorOverlay.appendChild(cursorElement);
    
    // Store cursor info
    this.cursors.set(cursor.session_id, { element: cursorElement, ...cursor });
    
    // Auto-fade label after 5 seconds (longer for better UX)
    setTimeout(() => {
      if (label.parentElement && !cursor.typing) {
        label.style.opacity = '0.8';
        label.style.transform = 'scale(0.95)';
        label.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
      }
    }, 5000);
    
    // Add entrance animation
    cursorElement.style.opacity = '0';
    cursorElement.style.transform = 'scale(0.8) translateY(4px)';
    
    requestAnimationFrame(() => {
      cursorElement.style.opacity = '1';
      cursorElement.style.transform = 'scale(1) translateY(0)';
      cursorElement.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
    });
  }
  
  removeCursor(sessionId) {
    const cursor = document.getElementById(`cursor-${sessionId}`);
    const selection = document.getElementById(`selection-${sessionId}`);
    
    if (cursor) cursor.remove();
    if (selection) selection.remove();
    
    this.cursors.delete(sessionId);
  }
  
  renderSelection(sessionId, color, selection) {
    const startCoords = this.getCoordinatesFromPosition(selection.start);
    const endCoords = this.getCoordinatesFromPosition(selection.end);
    
    if (startCoords && endCoords) {
      const selectionEl = document.createElement('div');
      selectionEl.id = `selection-${sessionId}`;
      selectionEl.className = 'absolute collaborative-selection';
      selectionEl.style.left = `${Math.min(startCoords.left, endCoords.left)}px`;
      selectionEl.style.top = `${startCoords.top}px`;
      selectionEl.style.width = `${Math.abs(endCoords.left - startCoords.left)}px`;
      selectionEl.style.height = '1.5rem';
      selectionEl.style.backgroundColor = color;
      selectionEl.style.color = color;
      selectionEl.style.opacity = '0.25';
      selectionEl.style.zIndex = '20';
      selectionEl.style.borderRadius = '2px';
      selectionEl.style.boxShadow = `0 0 3px ${color}30`;
      selectionEl.style.pointerEvents = 'none';
      
      // Add subtle border
      selectionEl.style.border = `1px solid ${color}50`;
      
      // Entrance animation
      selectionEl.style.transform = 'scaleX(0)';
      selectionEl.style.transformOrigin = 'left center';
      
      this.cursorOverlay.appendChild(selectionEl);
      
      requestAnimationFrame(() => {
        selectionEl.style.transform = 'scaleX(1)';
        selectionEl.style.transition = 'transform 0.2s ease-out';
      });
    }
  }
  
  lightenColor(color, percent) {
    // Convert hex to RGB, lighten, and convert back
    const hex = color.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16);
    const g = parseInt(hex.substr(2, 2), 16);
    const b = parseInt(hex.substr(4, 2), 16);
    
    const lighten = (c) => Math.min(255, Math.floor(c + (255 - c) * (percent / 100)));
    
    const newR = lighten(r).toString(16).padStart(2, '0');
    const newG = lighten(g).toString(16).padStart(2, '0');
    const newB = lighten(b).toString(16).padStart(2, '0');
    
    return `#${newR}${newG}${newB}`;
  }
  
  getCoordinatesFromPosition(position) {
    // Create temporary element to measure text position
    const tempDiv = document.createElement('div');
    const styles = window.getComputedStyle(this.editor);
    
    // Copy editor styles
    tempDiv.style.position = 'absolute';
    tempDiv.style.visibility = 'hidden';
    tempDiv.style.whiteSpace = 'pre-wrap';
    tempDiv.style.wordWrap = 'break-word';
    tempDiv.style.font = styles.font;
    tempDiv.style.padding = styles.padding;
    tempDiv.style.border = styles.border;
    tempDiv.style.width = this.editor.offsetWidth + 'px';
    
    // Add text up to position
    const textUpToPosition = this.editor.value.substring(0, position);
    tempDiv.textContent = textUpToPosition;
    
    // Add marker
    const marker = document.createElement('span');
    marker.textContent = '|';
    marker.style.color = 'transparent';
    tempDiv.appendChild(marker);
    
    document.body.appendChild(tempDiv);
    
    // Get position
    const markerRect = marker.getBoundingClientRect();
    const editorRect = this.editor.getBoundingClientRect();
    
    const coords = {
      left: markerRect.left - editorRect.left + this.editor.scrollLeft,
      top: markerRect.top - editorRect.top + this.editor.scrollTop
    };
    
    document.body.removeChild(tempDiv);
    return coords;
  }
  
  adjustAllCursors(operation) {
    this.cursors.forEach((cursor, sessionId) => {
      const newPosition = this.adjustCursorForOperation(cursor.position, operation);
      
      // Update cursor position if it changed
      if (newPosition !== cursor.position) {
        cursor.position = Math.max(0, Math.min(newPosition, this.content.length));
        
        // Update selection if it exists
        if (cursor.selection) {
          cursor.selection = {
            start: Math.max(0, Math.min(this.adjustCursorForOperation(cursor.selection.start, operation), this.content.length)),
            end: Math.max(0, Math.min(this.adjustCursorForOperation(cursor.selection.end, operation), this.content.length))
          };
        }
        
        // Re-render the cursor with updated position
        this.updateUserCursor({
          session_id: sessionId,
          name: cursor.name,
          color: cursor.color,
          position: cursor.position,
          selection: cursor.selection,
          typing: cursor.typing || false
        });
      }
    });
  }
  
  requestSync() {
    console.log("🔄 Requesting sync from server");
    this.channel.push("request_sync", {})
      .receive("ok", (response) => {
        console.log("📊 Received sync response:", response);
        this.handleSyncResponse(response);
      })
      .receive("error", (error) => {
        console.error("❌ Sync request failed:", error);
      });
  }
  
  handleSyncResponse(state) {
    console.log("🔧 Processing sync response");
    
    const serverContent = state.content || '';
    const currentEditorContent = this.editor.value || '';
    
    // Update internal state
    this.content = serverContent;
    this.version = state.version || 0;
    
    // Update preview after sync
    this.updatePreview();
    
    // Force sync editor if content differs
    if (currentEditorContent !== serverContent) {
      console.log(`🚨 Content desync detected! Editor: "${currentEditorContent}" vs Server: "${serverContent}"`);
      this.updateEditorContent();
    } else {
      console.log("✅ Content already in sync");
    }
    
    // Update users
    if (state.users) {
      Object.values(state.users).forEach(user => {
        if (user.session_id !== this.userId) {
          this.users.set(user.session_id, user);
        }
      });
    }
    
    // Update cursor positions
    if (state.cursor_positions) {
      state.cursor_positions.forEach(cursor => {
        if (cursor.session_id !== this.userId) {
          this.updateUserCursor(cursor);
        }
      });
    }
  }

  // Typing status management
  setTypingStatus(typing) {
    this.isTyping = typing;
    this.sendTypingStatus(typing);
  }

  sendTypingStatus(typing) {
    if (this.channel) {
      this.channel.push("typing_status", { typing: typing });
    }
  }

  scheduleTypingStop() {
    clearTimeout(this.typingTimeout);
    this.typingTimeout = setTimeout(() => {
      this.setTypingStatus(false);
    }, 1000); // Stop typing indicator after 1 second of inactivity
  }
  
  // Markdown Preview Methods
  initializeMarkdownPreview() {
    // Find preview elements in split and preview modes
    this.previewElement = document.getElementById('markdown-preview');
    this.previewFullElement = document.getElementById('markdown-preview-full');
    
    if (this.previewElement || this.previewFullElement) {
      // Initialize markdown preview instances
      if (this.previewElement) {
        this.markdownPreview = new MarkdownPreview(this.previewElement);
      }
      if (this.previewFullElement) {
        this.markdownPreviewFull = new MarkdownPreview(this.previewFullElement);
      }
      
      // Initial render
      this.updatePreview();
      
      console.log("🎨 Real-time markdown preview initialized");
    }
  }
  
  updatePreview() {
    // Update both preview elements if they exist
    if (this.markdownPreview) {
      this.markdownPreview.updatePreview(this.content);
    }
    if (this.markdownPreviewFull) {
      this.markdownPreviewFull.updatePreview(this.content);
    }
  }
  
  destroy() {
    clearTimeout(this.typingTimeout);
    clearTimeout(this.cursorUpdateTimeout);
    clearInterval(this.syncInterval);
    
    if (this.channel) {
      this.channel.leave();
    }
    if (this.socket) {
      this.socket.disconnect();
    }
    if (this.cursorOverlay) {
      this.cursorOverlay.innerHTML = '';
    }
    
    // Clean up markdown preview instances
    if (this.markdownPreview) {
      this.markdownPreview.clearPreview();
      this.markdownPreview = null;
    }
    if (this.markdownPreviewFull) {
      this.markdownPreviewFull.clearPreview();
      this.markdownPreviewFull = null;
    }
  }

  // Phoenix Channel user event handlers
  handleUserJoined(payload) {
    const { session_id, user } = payload;
    if (session_id !== this.userId) {
      console.log("👤 User joined:", user.name);
      this.users.set(session_id, user);
      // Always show cursor for joined users, even if at position 0
      this.updateUserCursor({
        session_id,
        name: user.name,
        color: user.color,
        position: user.cursor_position || 0,
        selection: user.selection,
        typing: user.typing || false
      });
    }
  }

  handleUserLeft(payload) {
    const { session_id } = payload;
    if (session_id !== this.userId) {
      console.log("👋 User left:", session_id);
      this.users.delete(session_id);
      this.removeCursor(session_id);
    }
  }

  handleTypingUpdate(payload) {
    const { session_id, typing } = payload;
    if (session_id !== this.userId) {
      const user = this.users.get(session_id);
      if (user) {
        user.typing = typing;
        console.log(`⌨️ ${user.name} typing: ${typing}`);
        this.updateUserCursor({
          session_id,
          name: user.name,
          color: user.color,
          position: user.cursor_position || 0,
          selection: user.selection,
          typing: typing
        });
      }
    }
  }

  handleCursorUpdate(payload) {
    const { session_id, position, selection } = payload;
    
    if (session_id === this.userId) {
      return; // Ignore our own cursor updates
    }
    
    const user = this.users.get(session_id);
    if (user) {
      user.cursor_position = position;
      user.selection = selection;
      console.log(`🎯 Cursor update for ${user.name}: pos ${position}`);
      this.updateUserCursor({
        session_id,
        name: user.name,
        color: user.color,
        position: position,
        selection: selection,
        typing: user.typing || false
      });
    }
  }
}

// Phoenix LiveView hook that initializes the collaborative editor
export const CollaborativeDocumentEditor = {
  mounted() {
    const documentId = this.el.dataset.documentId;
    const userId = this.el.dataset.userId;
    const userName = this.el.dataset.userName;
    
    this.collaborativeEditor = new CollaborativeEditor(
      this.el, 
      documentId, 
      userId, 
      userName
    );

    // Phoenix Channels handle all real-time sync
    // LiveView only handles UI-specific events (modals, etc.)
  },
  
  destroyed() {
    if (this.collaborativeEditor) {
      this.collaborativeEditor.destroy();
    }
  }
};
