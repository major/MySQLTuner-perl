import './styles/index.css'
import './styles/sidebar.css'

import './router'

document.addEventListener('DOMContentLoaded', () => {
  console.log('MySQLTuner Website Initialized');

  // Sidebar toggle for mobile
  const toggle = document.getElementById('sidebar-toggle');
  const sidebar = document.querySelector('.sidebar');

  if (toggle && sidebar) {
    toggle.addEventListener('click', () => {
      sidebar.classList.toggle('open');
    });
  }

  // Handle navigation events
  const handleNavigation = () => {
    // Scroll to top when route changes
    window.scrollTo({ top: 0, behavior: 'smooth' });

    // Auto-close sidebar on mobile
    if (sidebar) sidebar.classList.remove('open');
  };

  // Listen for hash changes
  window.addEventListener('hashchange', handleNavigation);

  // Initial link interaction
  document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
      // Small delay to ensure route change before scroll if using router
      setTimeout(handleNavigation, 50);
    });
  });
});
