/**
 * MarkdownToolbar - Enhanced markdown formatting toolbar
 * 
 * Features:
 * - Text formatting (bold, italic, strikethrough)
 * - List creation and management
 * - Link and image insertion
 * - Code blocks and blockquotes
 * - Table insertion
 * - Integration with collaborative editor
 */

export class MarkdownToolbar {
  constructor(element) {
    this.button = element;
    this.action = element.dataset.action;
    this.targetId = element.dataset.target;
    this.target = document.getElementById(this.targetId);
    
    if (!this.target) {
      console.warn(`MarkdownToolbar: Target element ${this.targetId} not found`);
      return;
    }
    
    this.setupEventListeners();
    this.setupKeyboardShortcuts();
  }
  
  setupEventListeners() {
    this.button.addEventListener('click', (e) => {
      e.preventDefault();
      this.handleAction(this.action);
    });
    
    // Handle overflow menu toggle for mobile
    if (this.action === 'toggle_menu') {
      this.setupOverflowMenu();
    }
  }
  
  setupOverflowMenu() {
    // Check if button has a parent element
    if (!this.button.parentElement) {
      console.warn('MarkdownToolbar: Button has no parent element');
      return;
    }
    
    const menu = this.button.parentElement.querySelector('.more-options-menu');
    if (menu) {
      this.button.addEventListener('click', (e) => {
        e.stopPropagation();
        menu.classList.toggle('hidden');
      });
      
      // Close menu when clicking outside
      document.addEventListener('click', (e) => {
        // Add null check for parentElement
        if (this.button.parentElement && !this.button.parentElement.contains(e.target)) {
          menu.classList.add('hidden');
        }
      });
    }
  }
  
  setupKeyboardShortcuts() {
    this.target.addEventListener('keydown', (e) => {
      // Check for common keyboard shortcuts
      if (e.ctrlKey || e.metaKey) {
        switch (e.key.toLowerCase()) {
          case 'b':
            e.preventDefault();
            this.handleAction('bold');
            break;
          case 'i':
            e.preventDefault();
            this.handleAction('italic');
            break;
          case 'k':
            e.preventDefault();
            this.handleAction('link');
            break;
          case 'z':
            if (e.shiftKey) {
              e.preventDefault();
              this.handleAction('redo');
            } else {
              e.preventDefault();
              this.handleAction('undo');
            }
            break;
          case 'y':
            e.preventDefault();
            this.handleAction('redo');
            break;
        }
      }
    });
  }
  
  handleAction(action) {
    switch (action) {
      case 'bold':
        this.wrapSelection('**', '**', 'bold text');
        break;
      case 'italic':
        this.wrapSelection('*', '*', 'italic text');
        break;
      case 'strikethrough':
        this.wrapSelection('~~', '~~', 'strikethrough text');
        break;
      case 'unordered_list':
        this.insertList('- ');
        break;
      case 'ordered_list':
        this.insertList('1. ');
        break;
      case 'blockquote':
        this.insertBlockquote();
        break;
      case 'code_block':
        this.insertCodeBlock();
        break;
      case 'table':
        this.insertTable();
        break;
      case 'link':
        this.insertLink();
        break;
      case 'image':
        this.insertImage();
        break;
      case 'horizontal_rule':
        this.insertHorizontalRule();
        break;
      case 'undo':
        this.performUndo();
        break;
      case 'redo':
        this.performRedo();
        break;
    }
    
    // Trigger input event to sync with collaborative editor
    this.triggerInputEvent();
  }
  
  wrapSelection(prefix, suffix, placeholder) {
    const start = this.target.selectionStart;
    const end = this.target.selectionEnd;
    const selectedText = this.target.value.substring(start, end);
    const text = selectedText || placeholder;
    const newText = prefix + text + suffix;
    
    this.replaceSelection(newText);
    
    // Set cursor position
    if (!selectedText) {
      // If no text was selected, position cursor inside the formatting
      this.target.setSelectionRange(
        start + prefix.length,
        start + prefix.length + text.length
      );
    } else {
      // If text was selected, position cursor after the formatting
      this.target.setSelectionRange(
        start + newText.length,
        start + newText.length
      );
    }
    
    this.target.focus();
  }
  
  insertList(prefix) {
    const start = this.target.selectionStart;
    const end = this.target.selectionEnd;
    const value = this.target.value;
    
    // Get the current line
    const lineStart = value.lastIndexOf('\n', start - 1) + 1;
    const lineEnd = value.indexOf('\n', end);
    const lineEndPos = lineEnd === -1 ? value.length : lineEnd;
    const currentLine = value.substring(lineStart, lineEndPos);
    
    // Check if the line already has list formatting
    const unorderedMatch = currentLine.match(/^(\s*)[-*+]\s/);
    const orderedMatch = currentLine.match(/^(\s*)\d+\.\s/);
    
    if (prefix === '- ' && unorderedMatch) {
      // Remove unordered list formatting
      const indent = unorderedMatch[1];
      const newLine = currentLine.replace(/^(\s*)[-*+]\s/, indent);
      this.replaceLine(lineStart, lineEndPos, newLine);
    } else if (prefix === '1. ' && orderedMatch) {
      // Remove ordered list formatting
      const indent = orderedMatch[1];
      const newLine = currentLine.replace(/^(\s*)\d+\.\s/, indent);
      this.replaceLine(lineStart, lineEndPos, newLine);
    } else {
      // Add list formatting
      const indent = currentLine.match(/^(\s*)/)?.[1] || '';
      const newLine = indent + prefix + currentLine.trimStart();
      this.replaceLine(lineStart, lineEndPos, newLine);
    }
    
    this.target.focus();
  }
  
  insertBlockquote() {
    const start = this.target.selectionStart;
    const value = this.target.value;
    
    // Get the current line
    const lineStart = value.lastIndexOf('\n', start - 1) + 1;
    const lineEnd = value.indexOf('\n', start);
    const lineEndPos = lineEnd === -1 ? value.length : lineEnd;
    const currentLine = value.substring(lineStart, lineEndPos);
    
    // Check if line already has blockquote formatting
    if (currentLine.startsWith('> ')) {
      // Remove blockquote formatting
      const newLine = currentLine.substring(2);
      this.replaceLine(lineStart, lineEndPos, newLine);
    } else {
      // Add blockquote formatting
      const newLine = '> ' + currentLine;
      this.replaceLine(lineStart, lineEndPos, newLine);
    }
    
    this.target.focus();
  }
  
  insertCodeBlock() {
    const start = this.target.selectionStart;
    const end = this.target.selectionEnd;
    const selectedText = this.target.value.substring(start, end);
    const codeBlock = selectedText ? 
      `\`\`\`\n${selectedText}\n\`\`\`` : 
      '```\ncode here\n```';
    
    this.replaceSelection(codeBlock);
    
    // Position cursor
    if (!selectedText) {
      this.target.setSelectionRange(start + 4, start + 13); // Select "code here"
    }
    
    this.target.focus();
  }
  
  insertTable() {
    const table = [
      '| Header 1 | Header 2 | Header 3 |',
      '|----------|----------|----------|',
      '| Cell 1   | Cell 2   | Cell 3   |',
      '| Cell 4   | Cell 5   | Cell 6   |'
    ].join('\n');
    
    this.insertAtCursor('\n' + table + '\n\n');
    this.target.focus();
  }
  
  insertLink() {
    const start = this.target.selectionStart;
    const end = this.target.selectionEnd;
    const selectedText = this.target.value.substring(start, end);
    
    if (selectedText) {
      // If text is selected, make it a link
      const linkText = selectedText;
      const url = prompt('Enter URL:', 'https://');
      if (url) {
        const link = `[${linkText}](${url})`;
        this.replaceSelection(link);
      }
    } else {
      // If no text selected, insert link template
      const linkText = prompt('Enter link text:', 'link text');
      const url = prompt('Enter URL:', 'https://');
      if (linkText && url) {
        const link = `[${linkText}](${url})`;
        this.insertAtCursor(link);
      }
    }
    
    this.target.focus();
  }
  
  insertImage() {
    const altText = prompt('Enter image alt text:', 'image');
    const url = prompt('Enter image URL:', 'https://');
    
    if (altText && url) {
      const image = `![${altText}](${url})`;
      this.insertAtCursor(image);
    }
    
    this.target.focus();
  }
  
  insertHorizontalRule() {
    this.insertAtCursor('\n---\n');
    this.target.focus();
  }
  
  performUndo() {
    document.execCommand('undo');
    this.triggerInputEvent();
  }
  
  performRedo() {
    document.execCommand('redo');
    this.triggerInputEvent();
  }
  
  // Utility methods
  
  replaceSelection(newText) {
    const start = this.target.selectionStart;
    const end = this.target.selectionEnd;
    const value = this.target.value;
    
    this.target.value = value.substring(0, start) + newText + value.substring(end);
    this.target.setSelectionRange(start + newText.length, start + newText.length);
  }
  
  replaceLine(lineStart, lineEnd, newLine) {
    const value = this.target.value;
    this.target.value = value.substring(0, lineStart) + newLine + value.substring(lineEnd);
    this.target.setSelectionRange(lineStart + newLine.length, lineStart + newLine.length);
  }
  
  insertAtCursor(text) {
    const start = this.target.selectionStart;
    const value = this.target.value;
    
    this.target.value = value.substring(0, start) + text + value.substring(start);
    this.target.setSelectionRange(start + text.length, start + text.length);
  }
  
  triggerInputEvent() {
    // Trigger input event to notify collaborative editor of changes
    const event = new Event('input', {
      bubbles: true,
      cancelable: true,
    });
    this.target.dispatchEvent(event);
  }
}

// Phoenix LiveView Hook
export const MarkdownToolbarHook = {
  mounted() {
    this.toolbarInstance = new MarkdownToolbar(this.el);
  },
  
  destroyed() {
    if (this.toolbarInstance) {
      // Clean up any event listeners if needed
      this.toolbarInstance = null;
    }
  }
};

// Enhanced toolbar functionality for collaborative editing integration
export class CollaborativeToolbar extends MarkdownToolbar {
  constructor(element, collaborativeEditor) {
    super(element);
    this.collaborativeEditor = collaborativeEditor;
  }
  
  triggerInputEvent() {
    super.triggerInputEvent();
    
    // Notify collaborative editor of content change
    if (this.collaborativeEditor) {
      this.collaborativeEditor.handleLocalInput({
        target: this.target
      });
    }
  }
  
  // Override methods to work better with operational transforms
  replaceSelection(newText) {
    const start = this.target.selectionStart;
    const end = this.target.selectionEnd;
    
    // Save collaborative state before making changes
    if (this.collaborativeEditor) {
      this.collaborativeEditor.pauseSync();
    }
    
    super.replaceSelection(newText);
    
    // Resume collaborative state after changes
    if (this.collaborativeEditor) {
      setTimeout(() => {
        this.collaborativeEditor.resumeSync();
      }, 10);
    }
  }
}

// Utility functions for markdown manipulation
export const MarkdownUtils = {
  /**
   * Check if current line has list formatting
   */
  isListItem(line) {
    return /^\s*[-*+]\s/.test(line) || /^\s*\d+\.\s/.test(line);
  },
  
  /**
   * Get the indentation level of a line
   */
  getIndentLevel(line) {
    const match = line.match(/^(\s*)/);
    return match ? match[1].length : 0;
  },
  
  /**
   * Format text with markdown syntax
   */
  formatText(text, type) {
    switch (type) {
      case 'bold':
        return `**${text}**`;
      case 'italic':
        return `*${text}*`;
      case 'strikethrough':
        return `~~${text}~~`;
      case 'code':
        return `\`${text}\``;
      default:
        return text;
    }
  },
  
  /**
   * Create a markdown table
   */
  createTable(rows = 3, cols = 3) {
    const headers = Array(cols).fill().map((_, i) => `Header ${i + 1}`);
    const separator = Array(cols).fill('----------');
    const cells = Array(rows - 1).fill().map((_, rowIndex) => 
      Array(cols).fill().map((_, colIndex) => `Cell ${rowIndex * cols + colIndex + 1}`)
    );
    
    const headerRow = `| ${headers.join(' | ')} |`;
    const separatorRow = `| ${separator.join(' | ')} |`;
    const dataRows = cells.map(row => `| ${row.join(' | ')} |`);
    
    return [headerRow, separatorRow, ...dataRows].join('\n');
  }
};