const { pool } = require('./db');

const list = async () =>
  (await pool.query('SELECT * FROM tasks ORDER BY id DESC')).rows;

const get = async (id) =>
  (await pool.query('SELECT * FROM tasks WHERE id = $1', [id])).rows[0] || null;

const create = async ({ title, description }) =>
  (await pool.query(
    'INSERT INTO tasks (title, description) VALUES ($1, $2) RETURNING *',
    [title, description]
  )).rows[0];

const update = async (id, { title, description, done }) =>
  (await pool.query(
    `UPDATE tasks SET
       title       = COALESCE($1, title),
       description = COALESCE($2, description),
       done        = COALESCE($3, done)
     WHERE id = $4 RETURNING *`,
    [title ?? null, description ?? null, done ?? null, id]
  )).rows[0] || null;

const remove = async (id) =>
  (await pool.query('DELETE FROM tasks WHERE id = $1', [id])).rowCount > 0;

module.exports = { list, get, create, update, remove };
