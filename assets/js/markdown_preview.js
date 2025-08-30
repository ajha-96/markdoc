/**
 * MarkdownPreview - Client-side markdown rendering with markdown-it
 * 
 * Features:
 * - Real-time markdown preview rendering
 * - No server roundtrips for preview updates
 * - Efficient client-side processing
 */

import MarkdownIt from 'markdown-it';

export class MarkdownPreview {
  constructor(previewElement) {
    this.previewElement = previewElement;
    
    // Initialize markdown-it with common options
    this.md = new MarkdownIt({
      html: true,        // Enable HTML tags in source
      breaks: true,      // Convert '\n' in paragraphs into <br>
      linkify: true,     // Autoconvert URL-like text to links
      typographer: true  // Enable some language-neutral replacement + quotes beautification
    });
    
    // Add syntax highlighting support if needed
    // this.md.use(markdownItHighlightJs);
    
    console.log("✨ MarkdownPreview initialized with client-side rendering");
  }
  
  /**
   * Update the preview pane with rendered markdown
   * @param {string} content - Raw markdown content
   */
  updatePreview(content) {
    if (!this.previewElement) {
      console.warn("⚠️ Preview element not found");
      return;
    }
    
    try {
      // Render markdown to HTML
      const html = this.md.render(content || '');
      
      // Update preview element
      this.previewElement.innerHTML = html;
      
      // Scroll to maintain position if needed
      // this.maintainScrollPosition();
      
    } catch (error) {
      console.error("❌ Error rendering markdown:", error);
      this.previewElement.innerHTML = `<p style="color: red;">Error rendering markdown: ${error.message}</p>`;
    }
  }
  
  /**
   * Get the current rendered HTML
   * @returns {string} Rendered HTML
   */
  getRenderedHtml() {
    return this.previewElement ? this.previewElement.innerHTML : '';
  }
  
  /**
   * Clear the preview
   */
  clearPreview() {
    if (this.previewElement) {
      this.previewElement.innerHTML = '';
    }
  }
  
  /**
   * Maintain scroll position during updates (optional)
   */
  maintainScrollPosition() {
    // Implementation for maintaining scroll position
    // Can be added later if needed
  }
  
  /**
   * Configure markdown-it options
   * @param {Object} options - markdown-it configuration options
   */
  configure(options) {
    this.md.configure(options);
  }
  
  /**
   * Add markdown-it plugins
   * @param {Function} plugin - markdown-it plugin function
   * @param {*} options - Plugin options
   */
  use(plugin, options) {
    this.md.use(plugin, options);
    return this;
  }
}