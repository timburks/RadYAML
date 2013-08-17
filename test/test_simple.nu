(load "RadYAML")

(class TestSimple is NuTestCase
     
     (- testSanity is
	(set d (dict hello:"hello" testing:(array 1 2 3)))
        (set yaml (d YAMLRepresentation))
	(assert_equal yaml "---\nhello: hello\ntesting:\n- 1\n- 2\n- 3\n...\n")
        (set d2 (yaml YAMLValue))
        (assert_equal d d2)))
