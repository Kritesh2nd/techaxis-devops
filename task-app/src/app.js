const path = require('path');
const express = require('express');
const repo = require('./tasksRepo');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '..', 'public')));

const isValidId = (v) => Number.isInteger(Number(v)) && Number(v) > 0;

app.post('/api/tasks', async (req, res, next) => {
  try {
    const { title, description = '' } = req.body;
    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({ error: 'title is required' });
    }
    res.status(201).json(await repo.create({ title: title.trim(), description }));
  } catch (err) { next(err); }
});

app.get('/api/tasks', async (_req, res, next) => {
  try { res.json(await repo.list()); } catch (err) { next(err); }
});

app.get('/api/tasks/:id', async (req, res, next) => {
  try {
    if (!isValidId(req.params.id)) return res.status(400).json({ error: 'invalid id' });
    const task = await repo.get(req.params.id);
    if (!task) return res.status(404).json({ error: 'task not found' });
    res.json(task);
  } catch (err) { next(err); }
});

app.put('/api/tasks/:id', async (req, res, next) => {
  try {
    if (!isValidId(req.params.id)) return res.status(400).json({ error: 'invalid id' });
    const { title, description, done } = req.body;
    if (title !== undefined && (typeof title !== 'string' || !title.trim())) {
      return res.status(400).json({ error: 'title cannot be empty' });
    }
    const task = await repo.update(req.params.id, { title: title?.trim(), description, done });
    if (!task) return res.status(404).json({ error: 'task not found' });
    res.json(task);
  } catch (err) { next(err); }
});

app.delete('/api/tasks/:id', async (req, res, next) => {
  try {
    if (!isValidId(req.params.id)) return res.status(400).json({ error: 'invalid id' });
    if (!(await repo.remove(req.params.id))) return res.status(404).json({ error: 'task not found' });
    res.status(204).end();
  } catch (err) { next(err); }
});

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'internal server error' });
});

module.exports = app;
