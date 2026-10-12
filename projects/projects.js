import { fetchJSON, renderProjects } from '../global.js';
import * as d3 from 'https://cdn.jsdelivr.net/npm/d3@7.9.0/+esm';

const projects = (await fetchJSON('../lib/projects.json')) ?? [];
const projectsContainer = document.querySelector('.projects');
const projectsTitle = document.querySelector('.projects-title');
const searchInput = document.querySelector('.searchBar');
const svg = d3.select('#projects-pie-plot');
const legend = d3.select('.legend');
const colors = d3.scaleOrdinal(d3.schemeTableau10);
const arcGenerator = d3.arc().innerRadius(0).outerRadius(50);

let query = '';
let selectedYear = null;

function projectMatchesQuery(project, searchQuery) {
  const values = Object.values(project).join('\n').toLowerCase();
  return values.includes(searchQuery.toLowerCase());
}

function getSearchedProjects() {
  return projects.filter((project) => projectMatchesQuery(project, query));
}

function getVisibleProjects() {
  return getSearchedProjects().filter(
    (project) => selectedYear === null || project.year === selectedYear,
  );
}

function updateTitle(count) {
  if (projectsTitle && Array.isArray(projects)) {
    projectsTitle.textContent = `Projects (${count})`;
  }
}

function updateSelectionStyles(data) {
  svg
    .selectAll('path')
    .attr('class', (_, index) =>
      data[index]?.label === selectedYear ? 'selected' : '',
    )
    .attr('aria-pressed', (_, index) =>
      data[index]?.label === selectedYear ? 'true' : 'false',
    );

  legend
    .selectAll('li')
    .attr('class', (_, index) =>
      data[index]?.label === selectedYear ? 'legend-item selected' : 'legend-item',
    )
    .attr('aria-pressed', (_, index) =>
      data[index]?.label === selectedYear ? 'true' : 'false',
    );
}

function renderVisibleProjects() {
  const visibleProjects = getVisibleProjects();
  renderProjects(visibleProjects, projectsContainer, 'h2');
  updateTitle(visibleProjects.length);
}

function setSelectedYear(year, data) {
  selectedYear = selectedYear === year ? null : year;
  updateSelectionStyles(data);
  renderVisibleProjects();
}

function renderPieChart(projectsGiven) {
  const rolledData = d3.rollups(
    projectsGiven,
    (items) => items.length,
    (project) => project.year,
  );

  const data = rolledData.map(([year, count]) => ({
    value: count,
    label: year,
  }));

  const sliceGenerator = d3.pie().value((d) => d.value);
  const arcData = sliceGenerator(data);
  const arcs = arcData.map((arc) => arcGenerator(arc));

  if (!data.some((item) => item.label === selectedYear)) {
    selectedYear = null;
  }

  svg.selectAll('path').remove();
  legend.selectAll('li').remove();

  arcs.forEach((arc, index) => {
    const year = data[index].label;
    const count = data[index].value;

    svg
      .append('path')
      .attr('d', arc)
      .attr('fill', colors(index))
      .attr('tabindex', 0)
      .attr('role', 'button')
      .attr('aria-label', `${year}: ${count} project${count === 1 ? '' : 's'}`)
      .on('click', () => setSelectedYear(year, data))
      .on('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          setSelectedYear(year, data);
        }
      });
  });

  data.forEach((item, index) => {
    legend
      .append('li')
      .attr('style', `--color:${colors(index)}`)
      .attr('class', 'legend-item')
      .attr('tabindex', 0)
      .attr('role', 'button')
      .attr('aria-label', `Show ${item.label} projects`)
      .html(`<span class="swatch"></span> ${item.label} <em>(${item.value})</em>`)
      .on('click', () => setSelectedYear(item.label, data))
      .on('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          setSelectedYear(item.label, data);
        }
      });
  });

  updateSelectionStyles(data);
}

function updatePage() {
  const searchedProjects = getSearchedProjects();
  renderPieChart(searchedProjects);
  renderVisibleProjects();
}

searchInput?.addEventListener('input', (event) => {
  query = event.target.value;
  updatePage();
});

updatePage();
