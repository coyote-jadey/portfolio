console.log('IT’S ALIVE!');

function $$(selector, context = document) {
  return Array.from(context.querySelectorAll(selector));
}

export async function fetchJSON(url) {
  try {
    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`Failed to fetch JSON: ${response.statusText}`);
    }

    return await response.json();
  } catch (error) {
    console.error('Error fetching or parsing JSON data:', error);
    return null;
  }
}

export function renderProjects(projects, containerElement, headingLevel = 'h2') {
  if (!containerElement) {
    return;
  }

  containerElement.innerHTML = '';

  if (!Array.isArray(projects) || projects.length === 0) {
    containerElement.textContent = 'No projects to display yet.';
    return;
  }

  const safeHeadingLevel = /^h[1-6]$/.test(headingLevel) ? headingLevel : 'h2';

  for (let project of projects) {
    let article = document.createElement('article');
    let heading = document.createElement(safeHeadingLevel);

    if (project.url) {
      let link = document.createElement('a');
      link.href = new URL(project.url, import.meta.url).href;
      link.textContent = project.title ?? 'Untitled project';
      heading.append(link);
    } else {
      heading.textContent = project.title ?? 'Untitled project';
    }

    article.append(heading);

    if (project.image) {
      let image = document.createElement('img');
      image.src = new URL(project.image, import.meta.url).href;
      image.alt = project.title ?? '';
      article.append(image);
    }

    let details = document.createElement('div');
    details.className = 'project-details';

    let description = document.createElement('p');
    description.textContent = project.description ?? '';
    details.append(description);

    if (project.year) {
      let year = document.createElement('p');
      year.className = 'project-year';
      year.textContent = project.year;
      details.append(year);
    }

    article.append(details);

    containerElement.append(article);
  }
}

export async function fetchGitHubData(username) {
  return fetchJSON(`https://api.github.com/users/${username}`);
}

const BASE_PATH =
  location.hostname === 'localhost' || location.hostname === '127.0.0.1'
    ? '/'
    : '/portfolio/';

let pages = [
  { url: '', title: 'Home' },
  { url: 'projects/', title: 'Projects' },
  { url: 'contact/', title: 'Contact' },
  { url: 'resume/', title: 'Resume' },
  { url: 'https://github.com/coyote-jadey', title: 'GitHub' },
];

let nav = document.createElement('nav');
nav.setAttribute('aria-label', 'Main navigation');
document.body.prepend(nav);

// Directory URLs and their index.html pages represent the same page.
function normalizePath(pathname) {
  return pathname.replace(/index\.html$/, '');
}

for (let p of pages) {
  let url = p.url;
  let title = p.title;

  if (!url.startsWith('http')) {
    url = BASE_PATH + url;
  }

  let a = document.createElement('a');
  a.href = url;
  a.textContent = title;

  if (
    a.host === location.host &&
    normalizePath(a.pathname) === normalizePath(location.pathname)
  ) {
    a.classList.add('current');
    a.setAttribute('aria-current', 'page');
  }

  if (a.host !== location.host) {
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
  }

  nav.append(a);
}

document.body.insertAdjacentHTML(
  'afterbegin',
  `
  <label class="color-scheme">
    Theme:
    <select>
      <option value="light dark">Automatic</option>
      <option value="light">Light</option>
      <option value="dark">Dark</option>
    </select>
  </label>`,
);

let select = document.querySelector('.color-scheme select');

function setColorScheme(value) {
  document.documentElement.style.setProperty('color-scheme', value);
  select.value = value;
}

try {
  let savedScheme = localStorage.getItem('colorScheme');
  if (['light dark', 'light', 'dark'].includes(savedScheme)) {
    setColorScheme(savedScheme);
  }
} catch {
  // Keep Automatic when browser settings prevent access to storage.
}

select.addEventListener('input', function (event) {
  let value = event.target.value;
  setColorScheme(value);

  try {
    localStorage.setItem('colorScheme', value);
  } catch {
    // The switch still works for this page when storage is unavailable.
  }
});

let form = document.querySelector('form[action^="mailto:"]');

form?.addEventListener('submit', function (event) {
  event.preventDefault();

  let data = new FormData(form);
  let params = [];

  for (let [name, value] of data) {
    params.push(`${encodeURIComponent(name)}=${encodeURIComponent(value)}`);
  }

  let url = form.action + '?' + params.join('&');
  location.href = url;
});
