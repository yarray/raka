def test_file(fname, expected)
    # does not actually test content, but save the expected text for test runner
    puts fname
    File.write(fname + '.expected', expected)
end