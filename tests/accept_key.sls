delay:
  module.run:
    - name: test.sleep
    - kargs:
      length: 5

accept_minion_key:
  salt.wheel:
    - name: key.accept
    - match: salt
    - require:
      - delay
