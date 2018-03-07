require 'spec_helper'

RSpec.describe Search::Dsl::Visitor do
  let(:contacts) {Arel::Table.new(:contacts)}

  def compile(node)
    Search::Dsl::Visitor.new.compile(node)
  end

  # it "should visit" do
  #   q = contacts
  #   search_query = {
  #       query: {
  #       }
  #   }
  #   expect(compile(q)).to eq(search_query)
  # end

  it 'should visit_Arel_SelectManager, which is a subquery' do
    q = contacts.project(:id, :name)
    search_query = {
      query: {
        projection: [
          { name: 'id' },
          { name: 'name' }
        ]
      }
    }
    expect(compile(q)).to eq(search_query)
  end

  describe 'Nodes::Equality' do
    it 'should escape strings' do
      test = contacts[:email].eq 'email@example.com'
      search_query = {
        filter: {
          attribute: {
            name: :email
          },
          parameter: {
            eq: 'email@example.com'
          }
        }
      }
      expect(compile(test)).to eq(search_query)
    end

    it 'should handle false' do
      test = contacts[:active].eq false
      search_query = {
        filter: {
          attribute: {
            name: :active
          },
          parameter: {
            eq: false
          }
        }
      }
      expect(compile(test)).to eq(search_query)
    end

    it 'should handle nil' do
      test = contacts[:email].eq nil
      search_query = {
        filter: {
          attribute: {
            name: :email
          },
          parameter: {
            is_null: true
          }
        }
      }
      expect(compile(test)).to eq(search_query)
    end
  end


  describe 'Nodes::NotEqual' do
    it 'should escape strings' do
      test = contacts[:email].not_eq 'email@example.com'
      search_query = {
        not: {
          filter: {
            attribute: {
              name: :email
            },
            parameter: {
              eq: 'email@example.com'
            }
          }
        }
      }
      expect(compile(test)).to eq(search_query)
    end

    it 'should handle nil' do
      test = contacts[:email].not_eq nil
      search_query = {
        filter: {
          attribute: {
            name: :email
          },
          parameter: {
            is_null: false
          }
        }
      }
      expect(compile(test)).to eq(search_query)
    end
  end

  it 'should visit_Arel_Nodes_And' do
    test = contacts[:id].eq(1).and(contacts[:id].eq(2))
    search_query = {
      and: [
        {
          filter: {
            attribute: {
              name: :id
            },
            parameter: {
              eq: 1
            }
          }
        },
        {
          filter: {
            attribute: {
              name: :id
            },
            parameter: {
              eq: 2
            }
          }
        }
      ]
    }
    expect(compile(test)).to eq(search_query)
  end

  it 'should visit_Arel_Nodes_Or' do
    test = contacts[:id].eq(1).or(contacts[:id].eq(2))
    search_query = {
      or: [
        {
          filter: {
            attribute: {
              name: :id
            },
            parameter: {
              eq: 1
            }
          }
        },
        {
          filter: {
            attribute: {
              name: :id
            },
            parameter: {
              eq: 2
            }
          }
        }
      ]
    }
    expect(compile(test)).to eq(search_query)
  end

  describe 'Nodes::Ordering' do
    it 'should know how to visit' do
      q = contacts.order(contacts[:email])
      search_query = {
        query: {
          sort: [
            attribute: {
              name: :email
            },
            order: :ascending
          ]
        }
      }
      expect(compile(q)).to eq(search_query)
    end

    it 'should handle order' do
      [
        [
          contacts.order(contacts[:email].asc),
          [{attribute: {name: :email}, order: :ascending}]
        ],
        [
          contacts.order(contacts[:email].desc),
          [{attribute: {name: :email}, order: :descending}]
        ],
        [
          contacts.order(contacts[:email].desc, contacts[:name].asc),
          [
            {attribute: {name: :email}, order: :descending},
            {attribute: {name: :name}, order: :ascending}
          ]
        ]
      ].each do |q, expected_sort|
        search_query = {
          query: {
            sort: expected_sort
          }
        }
        expect(compile(q)).to eq(search_query), "expected #{search_query}"
      end
    end
  end


  describe 'Complex query' do
    it 'should escape strings' do
      test = contacts
             .project(:id, :name, :email)
             .where(contacts[:id].eq(1))
             .where(contacts[:email].eq('email@example.com'))
             .order(contacts[:name].asc, contacts[:added_at].desc)
      search_query = {
        query: {
          projection: [
            { name: 'id' },
            { name: 'name' },
            { name: 'email' }
          ],
          filter: {
            and: [
              {
                filter: {
                  attribute: {
                    name: :id
                  },
                  parameter: {
                    eq: 1
                  }
                }
              },
              {
                filter: {
                  attribute: {
                    name: :email
                  },
                  parameter: {
                    eq: 'email@example.com'
                  }
                }
              }
            ]
          },
          sort: [
            {
              attribute: {
                name: :name
              },
              order: :ascending
            },
            {
              attribute: {
                name: :added_at
              },
              order: :descending
            }
          ]
        }
      }
      expect(compile(test)).to eq(search_query)
    end
  end
end
