const request = require('supertest');

// Replace the Postgres-backed repo with a tiny in-memory one: no database needed.
jest.mock('../src/tasksRepo', () => {
  let tasks = [];
  let nextId = 1;
  return {
    __reset: () => { tasks = []; nextId = 1; },
    list: async () => [...tasks].reverse(),
    get: async (id) => tasks.find((t) => t.id === Number(id)) || null,
    create: async ({ title, description }) => {
      const task = { id: nextId++, title, description, done: false };
      tasks.push(task);
      return task;
    },
    update: async (id, { title, description, done }) => {
      const task = tasks.find((t) => t.id === Number(id));
      if (!task) return null;
      if (title !== undefined) task.title = title;
      if (description !== undefined) task.description = description;
      if (done !== undefined) task.done = done;
      return task;
    },
    remove: async (id) => {
      const before = tasks.length;
      tasks = tasks.filter((t) => t.id !== Number(id));
      return tasks.length < before;
    },
  };
});

const repo = require('../src/tasksRepo');
const app = require('../src/app');

beforeEach(() => repo.__reset());

describe('Tasks CRUD', () => {
  test('creates a task', async () => {
    const res = await request(app).post('/api/tasks').send({ title: 'Write tests' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ id: 1, title: 'Write tests', done: false });
  });

  test('rejects a task without a title', async () => {
    const res = await request(app).post('/api/tasks').send({});
    expect(res.status).toBe(400);
  });

  test('lists tasks', async () => {
    await request(app).post('/api/tasks').send({ title: 'a' });
    await request(app).post('/api/tasks').send({ title: 'b' });
    const res = await request(app).get('/api/tasks');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(2);
  });

  test('gets one task, 404 when missing', async () => {
    await request(app).post('/api/tasks').send({ title: 'a' });
    expect((await request(app).get('/api/tasks/1')).body.title).toBe('a');
    expect((await request(app).get('/api/tasks/99')).status).toBe(404);
  });

  test('updates a task', async () => {
    await request(app).post('/api/tasks').send({ title: 'old' });
    const res = await request(app).put('/api/tasks/1').send({ title: 'new', done: true });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ title: 'new', done: true });
  });

  test('deletes a task', async () => {
    await request(app).post('/api/tasks').send({ title: 'bye' });
    expect((await request(app).delete('/api/tasks/1')).status).toBe(204);
    expect((await request(app).get('/api/tasks/1')).status).toBe(404);
  });
});
