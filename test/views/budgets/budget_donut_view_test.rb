require "test_helper"

class BudgetDonutViewTest < ActionView::TestCase
  test "renders available carry and consumption when no money is allocated this month" do
    family = families(:empty)
    category = family.categories.create!(name: "Annual service", color: "#6172F3")
    budget = family.budgets.create!(
      start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month,
      currency: "USD", budgeted_spending: 0, expected_income: 0
    )
    budget.budget_categories.create!(
      category: category, currency: "USD", budgeted_spending: 0,
      rollover_enabled: true, rolled_over_amount: 1_200
    )
    account = family.accounts.create!(
      accountable: Depository.new, name: "Fund checking", currency: "USD",
      balance: 2_000, status: "active"
    )
    account.entries.create!(
      entryable: Transaction.new(category: category), name: "Annual service payment",
      date: budget.start_date, amount: 300, currency: "USD"
    )

    render partial: "budgets/budget_donut", locals: { budget: budget, editable: false }

    assert_select "#segment_unused", text: /\$900.00/
    assert_select "[data-donut-chart-segments-value]" do |elements|
      segments = JSON.parse(elements.first["data-donut-chart-segments-value"])
      assert_equal 900, segments.find { |segment| segment["id"] == "unused" }["amount"].to_f
    end

    render partial: "budgets/budgeted_summary", locals: { budget: budget }

    assert_select "[style='width: 25.0%']"
    assert_select "span", text: /\$900.00 left/
  end

  test "renders hover content for uncategorized donut segment" do
    family = Family.create!(name: "Budget Donut View Repro", currency: "USD")
    account = Account.create!(
      family: family,
      accountable: Depository.new,
      name: "Checking",
      status: "active",
      currency: "USD",
      balance: 0
    )

    category = Category.create!(
      name: "Groceries #{SecureRandom.hex(4)}",
      family: family,
      color: "#407706",
      lucide_icon: "shopping-bag"
    )

    budget = Budget.create!(
      family: family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD",
      budgeted_spending: 100
    )

    BudgetCategory.create!(
      budget: budget,
      category: category,
      budgeted_spending: 100,
      currency: "USD"
    )

    Entry.create!(
      account: account,
      entryable: Transaction.create!(category: nil),
      date: Date.current,
      name: "Uncategorized hover spending",
      amount: 125,
      currency: "USD"
    )

    budget = Budget.find(budget.id)
    uncategorized = budget.uncategorized_budget_category

    html = render(partial: "budgets/budget_donut", locals: { budget: budget, editable: true })

    assert_includes html, "segment_#{uncategorized.id}"
    assert_includes html, uncategorized.category.display_name
  end
end
