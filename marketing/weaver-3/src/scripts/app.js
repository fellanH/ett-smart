document.addEventListener('DOMContentLoaded', () => {
    // Elements
    const dropZone = document.getElementById('drop-zone');
    const fileInput = document.getElementById('file-input');
    const viewEmpty = document.getElementById('view-empty');
    const viewDashboard = document.getElementById('view-dashboard');
    const viewTerminal = document.getElementById('view-terminal');
    const tableBody = document.querySelector('#data-table tbody');
    const tableHead = document.querySelector('#data-table thead');
    const fileNameDisplay = document.getElementById('file-name');
    const recordCountDisplay = document.getElementById('record-count');
    const searchInput = document.getElementById('search-input');
    const themeToggle = document.querySelector('.theme-toggle');
    const breadcrumbText = document.getElementById('breadcrumb-text');

    // Navigation
    const btnDashboard = document.getElementById('btn-dashboard');
    const btnUpload = document.getElementById('btn-upload'); // Reused for 'Home' logic
    const btnTerminal = document.getElementById('btn-terminal');

    // Terminal
    const terminalInput = document.getElementById('terminal-input');
    const btnRunCommand = document.getElementById('btn-run-command');
    const terminalOutput = document.getElementById('terminal-output');

    // State
    let currentData = [];
    let headers = [];
    let activeView = 'view-empty';

    // Theme Toggle
    themeToggle.addEventListener('click', () => {
        const icon = themeToggle.querySelector('i');
        if (icon.classList.contains('fa-moon')) {
            icon.classList.remove('fa-moon');
            icon.classList.add('fa-sun');
        } else {
            icon.classList.remove('fa-sun');
            icon.classList.add('fa-moon');
        }
    });

    // Navigation Logic
    function switchView(viewId) {
        [viewEmpty, viewDashboard, viewTerminal].forEach(view => {
            view.classList.add('hidden');
        });
        document.getElementById(viewId).classList.remove('hidden');

        // Update nav active state
        [btnDashboard, btnUpload, btnTerminal].forEach(btn => btn?.classList.remove('active'));

        if (viewId === 'view-dashboard' || viewId === 'view-empty') {
            if (currentData.length > 0) btnDashboard.classList.add('active');
            else btnUpload.classList.add('active');
            breadcrumbText.textContent = 'Home / Analysis';
        } else if (viewId === 'view-terminal') {
            btnTerminal.classList.add('active');
            breadcrumbText.textContent = 'Home / Terminal';
        }
    }

    btnDashboard.addEventListener('click', () => {
        if (currentData.length > 0) switchView('view-dashboard');
        else switchView('view-empty');
    });

    // Treat 'Upload' as reset/home if desired, or just show upload zone
    btnUpload.addEventListener('click', () => {
        switchView('view-empty');
    });

    btnTerminal.addEventListener('click', () => {
        switchView('view-terminal');
    });

    // File Upload Handlers
    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('drag-active');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('drag-active');
    });

    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('drag-active');
        const files = e.dataTransfer.files;
        if (files.length > 0 && files[0].name.endsWith('.csv')) {
            handleFile(files[0]);
        } else {
            alert('Please upload a valid CSV file.');
        }
    });

    fileInput.addEventListener('change', (e) => {
        if (e.target.files.length > 0) {
            handleFile(e.target.files[0]);
        }
    });

    function handleFile(file) {
        fileNameDisplay.textContent = file.name;

        Papa.parse(file, {
            header: true,
            skipEmptyLines: true,
            complete: function (results) {
                if (results.data && results.data.length > 0) {
                    headers = results.meta.fields;
                    currentData = results.data;
                    initializeDashboard();
                }
            },
            error: function (error) {
                alert('Error parsing CSV: ' + error.message);
            }
        });
    }

    function initializeDashboard() {
        switchView('view-dashboard');
        generateStats();
        renderTable(currentData);
        updateCounts(currentData.length);
    }

    function generateStats() {
        const container = document.getElementById('stats-container');
        container.innerHTML = '';
        createStatCard(container, 'Total Records', currentData.length);

        const statusCol = headers.find(h => h.toLowerCase().includes('status'));
        const turnoverCol = headers.find(h => h.toLowerCase().includes('omsättning') || h.toLowerCase().includes('turnover'));

        if (statusCol) {
            const activeCount = currentData.filter(r => r[statusCol] === 'Aktiv').length;
            createStatCard(container, 'Active Companies', activeCount);
        }

        if (turnoverCol) {
            let total = 0;
            let count = 0;
            currentData.forEach(row => {
                const val = parseFloat(row[turnoverCol]?.replace(/[^0-9.-]+/g, ""));
                if (!isNaN(val)) {
                    total += val;
                    count++;
                }
            });
            if (count > 0) {
                createStatCard(container, 'Total Turnover', formatCurrency(total));
            }
        }
    }

    function createStatCard(container, label, value) {
        const card = document.createElement('div');
        card.className = 'stat-card';
        card.innerHTML = `<div class="stat-label">${label}</div><div class="stat-value">${value}</div>`;
        container.appendChild(card);
    }

    function formatCurrency(num) {
        if (num > 1000000) return (num / 1000000).toFixed(1) + 'M';
        if (num > 1000) return (num / 1000).toFixed(1) + 'k';
        return num;
    }

    function renderTable(data) {
        tableHead.innerHTML = '<tr>' + headers.map(h => `<th>${h}</th>`).join('') + '</tr>';
        const displayData = data.slice(0, 100);
        tableBody.innerHTML = displayData.map(row => {
            return '<tr>' + headers.map(h => {
                let val = row[h] || '-';
                if (h.toLowerCase().includes('status')) {
                    if (val === 'Aktiv') return `<td><span class="status-badge status-active">${val}</span></td>`;
                    return `<td><span class="status-badge status-inactive">${val}</span></td>`;
                }
                return `<td>${val}</td>`;
            }).join('') + '</tr>';
        }).join('');
    }

    function updateCounts(count) {
        recordCountDisplay.textContent = `${count} records loaded`;
    }

    searchInput.addEventListener('input', (e) => {
        const term = e.target.value.toLowerCase();
        const filtered = currentData.filter(row => {
            return Object.values(row).some(val => String(val).toLowerCase().includes(term));
        });
        renderTable(filtered);
        updateCounts(filtered.length);
    });

    // --- TERMINAL LOGIC ---

    // Allow global setCommand
    window.setCommand = function (cmd) {
        terminalInput.value = cmd;
        terminalInput.focus();
    };

    function appendOutput(text, type = 'normal') {
        const line = document.createElement('div');
        line.className = `line ${type}`;
        line.textContent = text;
        terminalOutput.appendChild(line);
        terminalOutput.scrollTop = terminalOutput.scrollHeight;
    }

    async function executeCommand() {
        const command = terminalInput.value.trim();
        if (!command) return;

        appendOutput(`$ ${command}`, 'command');
        terminalInput.value = '';
        terminalInput.disabled = true;

        try {
            // Use absolute URL to ensure we hit the node server even if running via Live Server or file://
            const response = await fetch('http://localhost:3000/api/terminal/run', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ command })
            });

            const result = await response.json();

            if (result.stdout) appendOutput(result.stdout, 'success');
            if (result.stderr) appendOutput(result.stderr, 'error');
            if (result.error) appendOutput(`Execution Error: ${result.error}`, 'error');

        } catch (err) {
            appendOutput(`Network Error: ${err.message}`, 'error');
        } finally {
            terminalInput.disabled = false;
            terminalInput.focus();
        }
    }

    btnRunCommand.addEventListener('click', executeCommand);
    terminalInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') executeCommand();
    });
});
