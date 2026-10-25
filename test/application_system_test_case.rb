require "test_helper"
require_relative "support/post_builder"

# Chrome sometimes drops a click without any sign: no error, and the page never hears of it. The page counts the
# presses that reach it, so a click after which the count did not grow is known to be lost, and is made again from
# inside the page. A click that did arrive is never repeated, so a button that switches something on and off is
# never pressed twice. This sits on Capybara::Node::Element, which every click in a test goes through.
module ReliableClick
  WAIT_FOR_PRESS = 0.7

  def click(*keys, **options)
    # A click with keys held down or other options is left to Capybara
    return super unless keys.empty? && options.empty?
    # Any command sent to the browser while a confirm box is open makes it dismiss the box, so a click that opens
    # one is not checked afterwards. The tests that click such buttons repeat the click themselves if it was lost.
    return super if opens_confirm?

    description = clicked_thing
    before = presses_so_far
    result = super
    return result if before.nil? || press_arrived?(before)

    ReliableClick.report(session, "a click on #{description} did not reach the page, clicking it from the page itself")
    session.execute_script("arguments[0].click()", self)
    result
  end

  def self.report(session, text)
    Rails.logger.warn("SYSTEM TEST: #{text}")
    session.execute_script(<<~JS, text)
      try {
        const list = JSON.parse(sessionStorage.getItem("__trace") || "[]")
        list.push(Date.now() + " TEST: " + arguments[0])
        sessionStorage.setItem("__trace", JSON.stringify(list.slice(-400)))
      } catch (error) {}
    JS
  rescue StandardError
    nil
  end

  private
    def clicked_thing
      self[:"aria-label"].presence || self[:name].presence || text.to_s.strip.first(30).presence || tag_name
    rescue StandardError
      "an element"
    end

    def opens_confirm?
      session.evaluate_script("!!arguments[0].closest('[data-turbo-confirm]')", self)
    rescue StandardError
      false
    end

    def presses_so_far
      session.evaluate_script("Number(sessionStorage.getItem('__pointerdowns') || 0)")
    rescue StandardError
      nil
    end

    def press_arrived?(before)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + WAIT_FOR_PRESS

      loop do
        count = presses_so_far
        # No answer means the page is changing, which a click that arrived can do
        return true if count.nil? || count > before
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end
end

Capybara::Node::Element.prepend(ReliableClick)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActionView::RecordIdentifier
  include PostBuilder

  # Written into every page the browser opens. It keeps a diary of what happens there, in the session storage of the
  # tab, which survives the page being loaded again. A failed test prints it, so a click or typing that was lost
  # can be traced to what the page did at that moment. It also counts the presses that reach the page.
  TRACE_SCRIPT = <<~'JS'.freeze
    (() => {
      if (window.top !== window || !location.protocol.startsWith("http")) return

      const KEY = "__trace"
      const read = () => { try { return JSON.parse(sessionStorage.getItem(KEY) || "[]") } catch (error) { return [] } }
      const note = (text) => {
        try {
          const list = read()
          list.push(Date.now() + " " + text)
          sessionStorage.setItem(KEY, JSON.stringify(list.slice(-400)))
        } catch (error) {}
      }
      const describe = (node) => {
        if (!node || !node.tagName) return String(node)
        const label = node.getAttribute ? (node.getAttribute("aria-label") || node.getAttribute("name") || node.id || "") : ""
        const classes = String(node.className && node.className.baseVal !== undefined ? node.className.baseVal : node.className || "")
          .split(/\s+/).filter(Boolean).slice(0, 3).join(".")
        return node.tagName.toLowerCase() + (classes ? "." + classes : "") + (label ? "[" + label + "]" : "")
      }

      note("document starts " + location.pathname)
      document.addEventListener("DOMContentLoaded", () => {
        note("DOMContentLoaded")

        // Turbo replaces the whole body when it draws a page again
        new MutationObserver((records) => {
          for (const record of records) {
            for (const node of record.removedNodes) {
              if (node.tagName === "BODY") note("the BODY of the page was replaced")
            }
          }
        }).observe(document.documentElement, { childList: true })
      })
      window.addEventListener("load", () => note("load"))
      window.addEventListener("pagehide", () => note("pagehide, this page is being left"))

      try {
        new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) note(entry.name + " painted, " + Math.round(entry.startTime) + "ms after the page began")
        }).observe({ type: "paint", buffered: true })
      } catch (error) {}

      // How many presses have reached the page. A test that clicked can tell from it whether the click arrived.
      document.addEventListener("pointerdown", () => {
        try { sessionStorage.setItem("__pointerdowns", String(Number(sessionStorage.getItem("__pointerdowns") || 0) + 1)) } catch (error) {}
      }, true)

      // How many times something was typed into the page. A test that typed can tell from it whether the typing arrived.
      document.addEventListener("input", () => {
        try { sessionStorage.setItem("__inputs", String(Number(sessionStorage.getItem("__inputs") || 0) + 1)) } catch (error) {}
      }, true)

      // How many keys have reached the page. A test that pressed a key can tell from it whether the key arrived.
      document.addEventListener("keydown", () => {
        try { sessionStorage.setItem("__keydowns", String(Number(sessionStorage.getItem("__keydowns") || 0) + 1)) } catch (error) {}
      }, true)

      for (const type of ["pointerdown", "click", "submit", "input", "keydown"]) {
        document.addEventListener(type, (event) => note(type + " on " + describe(event.target)), true)
      }

      const turboEvents = [
        "turbo:click", "turbo:before-visit", "turbo:visit", "turbo:before-fetch-request",
        "turbo:before-fetch-response", "turbo:submit-start", "turbo:submit-end", "turbo:before-render",
        "turbo:render", "turbo:before-stream-render", "turbo:frame-load", "turbo:load"
      ]
      for (const type of turboEvents) {
        document.addEventListener(type, (event) => {
          note(type + (event.detail && event.detail.url ? " " + event.detail.url : ""))
        }, true)
      }
    })()
  JS

  # Chrome runs without a window. The extra options are what Chrome needs to start inside WSL.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-dev-shm-usage")
    # Chrome ignores clicks and typing until the page has painted for the first time. A test that acts right after
    # loading a page can lose its first click or its first letters. This switch, meant for tests, turns that off.
    options.add_argument("--allow-pre-commit-input")
    # Chrome without a window may hold back animation frames and timers of a page it thinks nobody is looking at
    options.add_argument("--disable-backgrounding-occluded-windows")
    options.add_argument("--disable-renderer-backgrounding")
    options.add_argument("--disable-background-timer-throttling")
    # The fonts come from Google over the internet. Tests do not need them, and their late arrival moves the text around.
    options.add_argument("--host-resolver-rules=MAP fonts.googleapis.com 127.0.0.1, MAP fonts.gstatic.com 127.0.0.1")
    # What the browser writes to its console is saved next to the screenshot of a failed test
    options.add_option("goog:loggingPrefs", { browser: "ALL" })
  end

  # A real browser is slower than a request in a test, so waiting for the page gets more time
  Capybara.default_max_wait_time = 10

  setup do
    response = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: TRACE_SCRIPT)
    @trace_script_id = response["identifier"]

    # The page is always treated as the one that has the focus, so keys and clicks are never held back
    begin
      page.driver.browser.execute_cdp("Emulation.setFocusEmulationEnabled", enabled: true)
    rescue StandardError
      nil
    end
  end

  teardown do
    if @trace_script_id
      page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @trace_script_id)
    end
  rescue StandardError
    nil
  end

  # Every page that is opened is given time to finish loading, so the first click or key press is never lost
  def visit(*)
    note_in_page("visit #{caller_locations(1, 1).first.lineno}")
    super
    wait_for_page_ready
  end

  # What the test itself does is written into the diary too, so it can be lined up with what the page did.
  # Typing that Chrome dropped never reaches the page, which counts the typing that does arrive, so it is typed
  # again. Typing that arrived is never repeated, even when the page was drawn again because of it.
  def fill_in(*args, **options, &block)
    note_in_page("fill_in #{args.first}")
    before = page_counter("__inputs")
    result = super
    retype_if_lost(args.first, options[:with], before)
    result
  end

  def click_button(*args, **options, &block)
    note_in_page("click_button #{args.first}")
    super
  end

  def click_link(*args, **options, &block)
    note_in_page("click_link #{args.first}")
    super
  end

  def attach_file(*args, **options, &block)
    note_in_page("attach_file #{args.first}")
    super
  end

  # Signs in through the log in page, as a person does
  def log_in_as(user, password: "password")
    visit new_session_path
    fill_in "login", with: user.username
    fill_in "password", with: password
    click_button "Log in"

    assert_selector "[aria-label='Open profile menu']"
    wait_for_page_ready
  end

  # Waits until the page is completely ready: loaded, painted, and every Stimulus controller that it asks for is
  # running. Typing or clicking earlier can do nothing, because the code that reacts is not there yet.
  def wait_for_page_ready
    wait_for("the page should be loaded, painted, and all its controllers running") do
      evaluate_script(<<~JS)
        (() => {
          if (document.readyState !== "complete") return false
          if (document.fonts && document.fonts.status !== "loaded") return false
          if (!performance.getEntriesByType("paint").some((entry) => entry.name === "first-contentful-paint")) return false

          const wanted = [...document.querySelectorAll("[data-controller]")].reduce(
            (total, element) => total + element.dataset.controller.split(/\\s+/).filter(Boolean).length, 0)
          if (wanted === 0) return true

          return !!window.Stimulus && Stimulus.controllers.length >= wanted
        })()
      JS
    end

    @page_origin = evaluate_script("performance.timeOrigin")
  end

  # Waits until a particular Stimulus controller is running on the page
  def wait_for_controller(identifier)
    wait_for_page_ready

    wait_for("the #{identifier} controller should start") do
      evaluate_script("!!window.Stimulus && Stimulus.controllers.some((c) => c.identifier === '#{identifier}')")
    end
  end

  # Waits until the block is true. Unlike a plain assert, it tries again for a few seconds.
  def wait_for(message)
    page.document.synchronize(Capybara.default_max_wait_time) do
      raise Capybara::ExpectationNotMet, message unless yield
    end
  end

  # Clicks a button that asks the browser to confirm, and answers OK. The question is answered inside the page,
  # not by a real browser box, which Chrome holds back while the comments window (itself a modal dialog) is open.
  # Returns the questions that the page asked, so a test can check them. Call it inside a within block to look for
  # the button in a part of the page.
  def click_and_accept_confirm(label)
    button = find(:button, label)
    execute_script("window.__confirmQuestions = []; window.confirm = (question) => { window.__confirmQuestions.push(question); return true }")
    # The click is made from the page, because Chrome keeps dropping real clicks on these buttons
    execute_script("arguments[0].click()", button)

    wait_for("the page should have asked to confirm") { evaluate_script("window.__confirmQuestions.length") > 0 }
    evaluate_script("window.__confirmQuestions")
  end

  # Sends Escape. If the page never heard of it, it is sent again.
  def press_escape
    3.times do
      before = page_counter("__keydowns")
      page.driver.browser.action.send_keys(:escape).perform
      break if before.nil? || counter_grew?("__keydowns", before)

      Rails.logger.warn("SYSTEM TEST: the Escape key did not reach the page, sending it again")
      note_in_page("the Escape key did not reach the page, sending it again")
    end
  end

  # Adds a line to the diary of the page
  def note_in_page(text)
    evaluate_script(<<~JS)
      (() => {
        try {
          const list = JSON.parse(sessionStorage.getItem("__trace") || "[]")
          list.push(Date.now() + " TEST: " + #{text.to_json})
          sessionStorage.setItem("__trace", JSON.stringify(list.slice(-400)))
        } catch (error) {}
        return true
      })()
    JS
  rescue StandardError
    nil
  end

  # Rails saves a screenshot of a failed test. A screenshot cannot show what the browser logged, whether the page
  # was drawn again, or what was typed, so those are written next to it. Only for a test that failed.
  def take_failed_screenshot
    super
    save_failure_details if failed?
  end

  def save_failure_details
    return unless Capybara::Session.instance_created?

    details = {
      "test" => name,
      "address" => safely { current_url },
      "ready state" => safely { evaluate_script("document.readyState") },
      "page loaded again since it was ready" => safely { @page_origin ? evaluate_script("performance.timeOrigin") != @page_origin : "unknown" },
      "focused element" => safely { evaluate_script("document.activeElement && document.activeElement.outerHTML.slice(0, 200)") },
      "visibility and focus" => safely { evaluate_script("document.visibilityState + ', has focus: ' + document.hasFocus()") },
      "field values" => safely { evaluate_script("Array.from(document.querySelectorAll('input, textarea')).map((field) => [ field.name, field.type == 'password' ? '(hidden)' : field.value ])") },
      "messages on the page" => safely { all("[role=alert], [role=status], .alert", visible: :all).map(&:text) },
      "controllers running" => safely { evaluate_script("window.Stimulus ? Stimulus.controllers.map((c) => c.identifier) : 'Stimulus is missing'") },
      "browser console" => safely { page.driver.browser.logs.get(:browser).map { |entry| "#{entry.level}: #{entry.message}" } },
      "diary of the page, in milliseconds from its first line" => safely { formatted_trace(evaluate_script("sessionStorage.getItem('__trace')")) }
    }

    text = details.map do |key, value|
      value.is_a?(Array) ? "#{key}:\n#{value.map { |line| "  #{line}" }.join("\n")}" : "#{key}: #{value}"
    end

    FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
    File.write(Rails.root.join("tmp/screenshots/#{name.gsub(/[^\w-]/, '_')}_details.txt"), text.join("\n"))
  end

  def formatted_trace(json)
    entries = JSON.parse(json || "[]")
    start = entries.first.to_s.split(" ", 2).first.to_i

    entries.map do |entry|
      time, text = entry.split(" ", 2)
      format("%6d  %s", time.to_i - start, text)
    end
  end

  def safely
    yield
  rescue StandardError => error
    "(could not read: #{error.class})"
  end

  private
    def page_counter(name)
      evaluate_script("Number(sessionStorage.getItem('#{name}') || 0)")
    rescue StandardError
      nil
    end

    def counter_grew?(name, before)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.7

      loop do
        count = page_counter(name)
        # No answer means the page is changing, which something that arrived can cause
        return true if count.nil? || count > before
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    def typing_arrived?(before)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 0.7

      loop do
        count = page_counter("__inputs")
        # No answer means the page is changing, which typing that arrived can cause
        return true if count.nil? || count > before
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    # Typing that did not arrive is typed again, at most twice. The second time the text is put into the field
    # from the page itself, because typing from outside kept getting lost.
    def retype_if_lost(locator, text, before)
      return if text.to_s.empty? || before.nil?

      2.times do |attempt|
        break if typing_arrived?(before)

        Rails.logger.warn("SYSTEM TEST: typing into #{locator} did not arrive, typing again")
        note_in_page("typing into #{locator} was lost, typing again")
        before = page_counter("__inputs")
        break if before.nil?

        field = find(:fillable_field, locator, wait: 0.3)
        if attempt.zero?
          field.set(text)
        else
          execute_script(
            "arguments[0].value = arguments[1]; arguments[0].dispatchEvent(new Event('input', { bubbles: true }))",
            field, text
          )
        end
      end
    rescue StandardError
      nil
    end
end
