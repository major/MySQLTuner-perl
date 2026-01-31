import { marked } from 'marked';

class Router {
  constructor() {
    this.routes = {
      'home': () => this.showHome(),
      'docs/overview': () => this.loadDoc('overview.md'),
      'docs/usage': () => this.loadDoc('usage.md'),
      'docs/internals': () => this.loadDoc('internals.md'),
      'docs/mysql_support': () => this.loadDoc('mysql_support.md'),
      'docs/mariadb_support': () => this.loadDoc('mariadb_support.md'),
      'releases': () => this.loadDoc('releases/index.md'),
      'faq': () => this.loadDoc('faq.md')
    };

    window.addEventListener('hashchange', () => this.handleRoute());
    this.handleRoute();
  }

  handleRoute() {
    let hash = window.location.hash.replace('#/', '') || 'home';

    // Update body class for layout toggle
    if (hash === 'home') {
      document.body.classList.replace('is-docs', 'is-home');
    } else {
      document.body.classList.replace('is-home', 'is-docs');
    }

    // Handle dynamic release routes
    if (hash.startsWith('docs/releases/')) {
      const releaseFile = hash.replace('docs/releases/', '');
      this.loadDoc(`releases/${releaseFile}`);
      return;
    }

    const handler = this.routes[hash] || (() => this.loadDoc('overview.md'));

    // Active link highlighting
    document.querySelectorAll('.nav-link').forEach(link => {
      link.classList.toggle('active', link.getAttribute('data-route') === hash);
    });

    handler();
  }

  showHome() {
    document.getElementById('home-view').style.display = 'block';
    document.getElementById('doc-view').style.display = 'none';
  }

  async loadDoc(file) {
    document.getElementById('home-view').style.display = 'none';
    document.getElementById('doc-view').style.display = 'block';
    const contentArea = document.getElementById('doc-rendered-content');

    contentArea.innerHTML = '<p class="loading">Loading documentation...</p>';

    try {
      // In Vite, we can fetch from src/docs during dev if configured, 
      // but for simplicity, we assume they are static assets or inlined.
      // For now, let's use a dynamic import or fetch from public/docs if we copy them there.
      const response = await fetch(`./docs/${file}`);
      if (!response.ok) throw new Error('Doc not found');
      const text = await response.text();
      contentArea.innerHTML = marked.parse(text);

      // Re-apply prism or syntax highlighting if needed
      window.scrollTo(0, 0);
    } catch (err) {
      contentArea.innerHTML = `<p class="error">Error loading documentation: ${err.message}</p>`;
    }
  }

  loadReleases() {
    // This would list the releases/ directory contents
    this.loadDoc('releases/index.md'); // Placeholder
  }
}

export default new Router();
