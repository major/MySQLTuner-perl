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

  // Close sidebar on link click (mobile)
  document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', () => {
      sidebar.classList.remove('open');
    });
  });
});
