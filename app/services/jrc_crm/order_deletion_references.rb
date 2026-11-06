# Traverses actual database foreign keys, including composite tenant constraints.
class JrcCrm::OrderDeletionReferences
  def initialize(nodes:, issues:)
    @nodes = nodes
    @issues = issues
  end

  def linked?(parent, child)
    incoming_keys.any? do |fk|
      fk['parent_table'] == parent[:record].class.table_name && fk['child_table'] == child[:record].class.table_name &&
        fk['columns'].all? { |child_column, parent_column| child[:record][child_column] == parent[:record][parent_column] }
    end
  end

  def protect!
    connection = ActiveRecord::Base.connection
    nodes.values.select { |n| n[:action] == 'delete' }.each do |node|
      r = node[:record]
      incoming_keys.select { |fk| fk['parent_table'] == r.class.table_name }.each do |fk|
        known = nodes.keys.select { |table, _id| table == fk['child_table'] }.map(&:last)
        condition = fk['columns'].map do |child_column, parent_column|
          "#{connection.quote_column_name(child_column)} = #{connection.quote(r[parent_column])}"
        end.join(' AND ')
        sql = "SELECT COUNT(*) FROM #{connection.quote_table_name(fk['child_table'])} WHERE #{condition}"
        sql += " AND id NOT IN (#{known.map(&:to_i).join(',')})" if known.any?
        count = connection.select_value(sql).to_i
        next unless count.positive?

        issues << "#{count} vínculo(s) adicional(is) em #{fk['child_table']}; revisão pelo módulo responsável."
        retain(r, issues.last)
      end
    end
    loop do
      parents = nodes.values.select do |parent|
        parent[:action] == 'delete' && nodes.values.any? { |child| child[:action] != 'delete' && linked?(parent, child) }
      end
      break if parents.empty?

      parents.each { |parent| retain(parent[:record], 'Registro necessário para manter vínculo e integridade de um dependente preservado.') }
    end
  end

  private

  attr_reader :nodes, :issues

  def retain(record, reason)
    node = nodes.fetch([record.class.table_name, record.id])
    node[:action] = 'preserve'
    node[:reason] = reason
  end

  def incoming_keys
    @incoming_keys ||= ActiveRecord::Base.connection.select_all(<<~SQL).to_a.group_by { |r| r['oid'] }.values.map do |rows|
      SELECT c.oid, child.relname AS child_table, ca.attname AS child_column,
             parent.relname AS parent_table, pa.attname AS parent_column
      FROM pg_constraint c
      JOIN pg_class child ON child.oid = c.conrelid
      JOIN pg_class parent ON parent.oid = c.confrelid
      JOIN pg_namespace ns ON ns.oid = child.relnamespace
      JOIN LATERAL generate_subscripts(c.conkey, 1) position ON true
      JOIN pg_attribute ca ON ca.attrelid = child.oid AND ca.attnum = c.conkey[position]
      JOIN pg_attribute pa ON pa.attrelid = parent.oid AND pa.attnum = c.confkey[position]
      WHERE c.contype = 'f' AND ns.nspname = current_schema()
    SQL
      rows.first.slice('child_table', 'parent_table').merge('columns' => rows.map { |r| [r['child_column'], r['parent_column']] })
    end
  end
end
