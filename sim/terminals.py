from nitro import DeviceInterface, Terminal, Register

di=DeviceInterface(
    name='Devices', 
    comment='My Test Device List', 
    terminal_list=[
        Terminal(
            name='Fast',
            comment='Fast test endpoint',
            regAddrWidth=16, 
            regDataWidth=16,
            register_list=[
                Register(name='fast_buf',
                         type='int',
                         mode='write',
                         width=16,
                         array=160,
                         init=0x78AB,
                         comment='test buffer'),
                Register(name='fast_reg',
                         type='int',
                         mode='write',
                         width=16,
                         init=10,
                         ),
                Register(name='wide_reg',
                         type='int',
                         mode='write',
                         width=73,
                         init=0x123fedcba9876543211,
                         ),
                ]
            ),
        Terminal(
            name='Slow',
            comment='Slow test endpoint',
            regAddrWidth=16, 
            regDataWidth=16,
            register_list=[
                Register(name='slow_buf',
                         type='int',
                         mode='write',
                         array=160,
                         width=16,
                         init=0x6543,
                         ),
                Register(name='slow_reg',
                         type='int',
                         mode='write',
                         width=16,
                         init=11,
                         ),
                ]
            ),
        Terminal(
            name='FastRAM',
            comment='Fast RAM Terminal',
            regAddrWidth=16, 
            regDataWidth=16,
            ),
        Terminal(
            name='SlowRAM',
            comment='Slow RAM Terminal',
            regAddrWidth=16, 
            regDataWidth=16,
            ),
        Terminal(
            name='NeverReadReady',
            comment='Never read ready test endpoint',
            regAddrWidth=16, 
            regDataWidth=16,
            register_list=[
                Register(name='reg2',
                         type='int',
                         mode='write',
                         width=16,
                         init=0x78AB,
                         ),
                Register(name='reg3',
                         type='int',
                         mode='write',
                         width=16,
                         init=10,
                         ),
                ]
            ),
        ]

    )


